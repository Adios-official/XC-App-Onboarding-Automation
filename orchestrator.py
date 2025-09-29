import pandas as pd
import os
import shutil
import subprocess
import sys
import zipfile
import json
from datetime import datetime
from typing import List, Set, Tuple, Optional, Any

# ==============================================================================
# --- CONFIGURATION & CONSTANTS ---
# ==============================================================================
EXCEL_FILE: str = 'config.xlsx'
TFVARS_DIR: str = 'tfvars'
MODULES_DIR: str = 'modules'

# ==============================================================================
# --- TERRAFORM & SYSTEM COMMAND FUNCTIONS ---
# ==============================================================================

def run_command(command: List[str], working_dir: str = '.') -> Tuple[int, List[str]]:
    """
    Runs a command in a subprocess, streams its output, and returns the result.
    """
    print(f"\n🚀 Running: {' '.join(command)}")
    try:
        process = subprocess.Popen(
            command,
            cwd=working_dir,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        output_lines = []
        for line in iter(process.stdout.readline, ''):
            print(line.strip())
            output_lines.append(line.strip())
        process.wait()
        rc = process.returncode
        print("✅ Command finished successfully." if rc == 0 else f"❌ Command failed with exit code {rc}")
        return rc, output_lines
    except FileNotFoundError:
        print(f"❌ Error: '{command[0]}' not found. Is it installed and in your PATH?")
        return -1, []
    except Exception as e:
        print(f"❌ An unexpected error occurred: {e}")
        return -1, []

def get_existing_workspaces(quiet: bool = False) -> Optional[Set[str]]:
    """
    Runs 'terraform workspace list' and returns a clean set of workspace names.
    """
    if not quiet:
        print_header("Checking for existing workspaces")

    try:
        process = subprocess.run(
            ['terraform', 'workspace', 'list'],
            capture_output=True, text=True, check=True
        )
        output_lines = process.stdout.splitlines()
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        if not quiet:
            print(f"❌ Could not list Terraform workspaces. Error: {e}")
        return None

    workspaces = {line.strip().replace('* ', '') for line in output_lines if line.strip()}
    return workspaces

def is_deployed(lb_name: str) -> bool:
    """
    Checks if a deployment is truly complete by verifying its state file.
    A deployment is considered complete if its state file exists
    and has a non-empty "resources" list.
    """
    state_file_path = os.path.join('terraform.tfstate.d', lb_name, 'terraform.tfstate')
    
    if not os.path.exists(state_file_path):
        return False
    
    try:
        with open(state_file_path, "r") as f:
            state_data = json.load(f)
        
        resources = state_data.get("resources", [])
        return len(resources) > 0
    except (json.JSONDecodeError, OSError, KeyError):
        # Invalid JSON, file error, or unexpected structure
        return False


# ==============================================================================
# --- DATA LOADING & FORMATTING FUNCTIONS ---
# ==============================================================================

def load_data() -> Optional[Tuple[pd.DataFrame, pd.Series]]:
    """Loads and returns the latest data from the Excel file."""
    try:
        df_lb = pd.read_excel(EXCEL_FILE, sheet_name='LoadBalancers')
        df_provider = pd.read_excel(EXCEL_FILE, sheet_name='Provider')
        return df_lb, df_provider.iloc[0]
    except Exception as e:
        print(f"❌ Error loading Excel file '{EXCEL_FILE}': {e}")
        return None, None

def generate_tfvars_content(row: Any, provider_config: pd.Series) -> str:
    """
    Generates the content for a well-structured and commented .tfvars file.
    """
    def format_string(value): return f'"{str(value)}"' if pd.notna(value) and value != '' else '""'
    def format_boolean(value): return str(bool(value)).lower()
    def format_list(value): 
        items = [f'"{item.strip()}"' for item in str(value).split(',')] if pd.notna(value) and value != '' else []
        return f'[{", ".join(items)}]'
    def format_map(value):
        items = str(value).split(',') if pd.notna(value) and value != '' else []
        map_entries = [f'"{k.strip()}" = "{v.strip()}"' for k, v in (item.split('=', 1) for item in items if '=' in item)]
        return f'{{{", ".join(map_entries)}}}' if map_entries else '{}'
    def format_number(value): return str(int(value)) if pd.notna(value) and value is not None else 'null'
    
    content = [
        "####################################################",
        "# Global & Provider Variables",
        "####################################################",
        f'api_p12_file = {format_string(provider_config.get("api_p12_file"))}',
        f'tenant_name  = {format_string(provider_config.get("tenant_name"))}',
        f'api_url      = {format_string(provider_config.get("api_url"))}',
        f'namespace    = {format_string(getattr(row, "namespace", None))}',
        ""
    ]
    
    if getattr(row, 'create_origin_pool', False):
        content.append("####################################################")
        content.append("# Origin Pool Variables (Top-Level)")
        content.append("####################################################")
        top_level_origin_vars = {
            "origin_pool_name": format_string, "origin_server_type": format_string,
            "origin_port": format_number, "origin_labels": format_map,
            "network_type": format_string, "site_name": format_string,
            "dns_name_private": format_string, "k8s_service_name": format_string,
            "ip_address_private": format_string, "ip_address_public": format_string,
            "dns_name_public": format_string
        }
        for var_name, formatter in top_level_origin_vars.items():
            if pd.notna(getattr(row, var_name, None)):
                content.append(f'{var_name.ljust(25)} = {formatter(getattr(row, var_name))}')
        content.append("")

    if getattr(row, 'create_origin_pool', False) and getattr(row, 'enable_healthcheck', False):
        content.append("####################################################")
        content.append("# Health Check Variables (Top-Level)")
        content.append("####################################################")
        if pd.notna(getattr(row, 'healthcheck_name', None)):
            content.append(f'healthcheck_name      = {format_string(getattr(row, "healthcheck_name"))}')
        if pd.notna(getattr(row, 'healthcheck_type', None)):
            content.append(f'healthcheck_type      = {format_string(getattr(row, "healthcheck_type"))}')
        if pd.notna(getattr(row, 'healthcheck_http_path', None)):
            content.append(f'healthcheck_http_path = {format_string(getattr(row, "healthcheck_http_path"))}')
        content.append("")

    # --- Load Balancer Object ---
    object_lines = []
    lb_object_attrs = {
        "lb_name": format_string, "domains": format_list,
        "lb_labels": format_map, "ip_threat_categories": format_list,
        "create_origin_pool": format_boolean, "existing_origin_pool_name": format_string,
        "enable_bot_defense": format_boolean, "advertise_on_public_default_vip": format_boolean,
        "advertise_custom": format_boolean, "custom_site_name": format_string,
        "site_network": format_string, "app_firewall_name": format_string,
        "enable_app_firewall": format_boolean, "enable_csrf": format_boolean,
        "csrf_policy_mode": format_string, "csrf_custom_domains": format_string, 
        "lb_type": format_string, "lb_port": format_number, 
        "add_hsts": format_boolean, "http_redirect": format_boolean, 
        "custom_cert_names": format_string, "custom_cert_namespace": format_string, 
        "enable_healthcheck": format_boolean
    }

    for attr, formatter in lb_object_attrs.items():
        value = getattr(row, attr, None)
        if pd.notna(value):
             object_lines.append(f'    {attr.ljust(31)} = {formatter(value)}')

    content.extend([
        "\n####################################################",
        "# Load Balancer Object",
        "####################################################",
        "load_balancers = [",
        "  {",
        ",\n".join(object_lines),
        "  }",
        "]"
    ])
    return "\n".join(content)


# ==============================================================================
# --- USER INTERFACE & MENU FUNCTIONS ---
# ==============================================================================

def print_header(title: str):
    """Prints a formatted header."""
    print("\n" + "="*50 + f"\n {title}\n" + "="*50)

def prompt_for_selection(items: List[Any], prompt_text: str, display_key: Optional[str] = None) -> Optional[Any]:
    """Displays a numbered list of items and prompts for a selection."""
    print(prompt_text)
    for i, item in enumerate(items):
        display_name = getattr(item, display_key) if display_key and hasattr(item, display_key) else item
        print(f"  {i + 1}. {display_name}")
    print("  0. Back to Main Menu")
    try:
        choice = int(input("Enter your choice: "))
        if choice == 0: return None
        if not 1 <= choice <= len(items): raise ValueError
        return items[choice - 1]
    except (ValueError, IndexError):
        print("❌ Invalid selection.")
        return None

def display_config(row: Any):
    """Displays the configuration from an Excel row in a readable format."""
    print_header(f"Configuration for: {row.lb_name}")
    
    origin_pool_keys = {
        'create_origin_pool', 'origin_pool_name', 'origin_server_type', 
        'origin_port', 'origin_labels', 'network_type', 'site_name',
        'dns_name_private', 'k8s_service_name', 'ip_address_private',
        'ip_address_public', 'dns_name_public'
    }
    https_keys = {'lb_type', 'lb_port', 'add_hsts', 'http_redirect', 'custom_cert_names', 'custom_cert_namespace'}
    healthcheck_keys = {'enable_healthcheck', 'healthcheck_name', 'healthcheck_type', 'healthcheck_http_path'}
    port_columns = {'lb_port', 'origin_port'}
    row_dict = row._asdict()

    print("\n## Load Balancer Details")
    lb_ignore_keys = origin_pool_keys | https_keys | healthcheck_keys | {'lb_name'}
    for key, value in row_dict.items():
        if pd.notna(value) and key not in lb_ignore_keys: 
            print(f"{key:<30}: {value}")
            
    print("\n## HTTPS Configuration")
    for key in https_keys:
        if key in row_dict and pd.notna(row_dict.get(key)):
            value = row_dict.get(key)
            display_value = int(value) if key in port_columns else value
            print(f"{key:<30}: {display_value}")
    
    if row_dict.get('create_origin_pool'):
        print("\n## New Origin Pool Details")
        for key, value in row_dict.items():
            if pd.notna(value) and key in origin_pool_keys:
                display_value = int(value) if key in port_columns else value
                print(f"{key:<30}: {display_value}")
        
        if row_dict.get('enable_healthcheck'):
            print("\n## Health Check Details")
            for key in healthcheck_keys:
                if pd.notna(row_dict.get(key)):
                    print(f"{key:<30}: {row_dict.get(key)}")
                    
    elif pd.notna(row_dict.get('existing_origin_pool_name')):
         print(f"\n## Existing Origin Pool: {row_dict.get('existing_origin_pool_name')}")


# ==============================================================================
# --- ORCHESTRATOR MENU HANDLERS ---
# ==============================================================================

def handle_apply_single(df_lb: pd.DataFrame, provider_config: pd.Series):
    """Handles the Apply (Deploy or Modify) action for a single LB."""
    print_header("Apply a Single Deployment (Deploy or Modify)")
    lb_rows = list(df_lb.itertuples(index=False))
    lb_row_to_apply = prompt_for_selection(lb_rows, "Select an LB to apply:", "lb_name")
    if lb_row_to_apply is None: return

    lb_name = lb_row_to_apply.lb_name
    tfvar_file = os.path.join(TFVARS_DIR, f"{lb_name}.tfvars")
    
    existing_workspaces = get_existing_workspaces(quiet=True)
    if existing_workspaces is None: return

    if lb_name in existing_workspaces:
        print(f"⚠️  Workspace '{lb_name}' already exists. This will apply modifications from Excel.")
        proceed = input("Do you want to proceed? (y/n): ").lower()
        if proceed != 'y':
            print("Apply cancelled."); return
    
    print(f"\nGenerating {tfvar_file} from Excel...")
    tfvars_content = generate_tfvars_content(lb_row_to_apply, provider_config)
    with open(tfvar_file, 'w') as f: f.write(tfvars_content)
    
    if lb_name not in existing_workspaces:
        run_command(['terraform', 'workspace', 'new', lb_name])
    else:
        run_command(['terraform', 'workspace', 'select', lb_name])
    run_command(['terraform', 'apply', f'-var-file={tfvar_file}', '-auto-approve'])

def handle_apply_all(df_lb: pd.DataFrame, provider_config: pd.Series):
    """Handles applying all pending LBs from the Excel sheet."""
    print_header("Apply All Pending Deployments")
    
    existing_workspaces = get_existing_workspaces(quiet=True)
    if existing_workspaces is None: return

    pending_lbs = [row for row in df_lb.itertuples(index=False) if not is_deployed(row.lb_name)]

    if not pending_lbs:
        print("All load balancers defined in Excel are already deployed. Nothing to do.")
        return

    print("The following pending load balancers will be deployed:")
    for lb in pending_lbs:
        print(f"  - {lb.lb_name}")
    
    proceed = input("Do you want to proceed? (y/n): ").lower()
    if proceed != 'y':
        print("Bulk apply cancelled."); return

    for lb_row in pending_lbs:
        lb_name = lb_row.lb_name
        print_header(f"Deploying: {lb_name}")
        tfvar_file = os.path.join(TFVARS_DIR, f"{lb_name}.tfvars")
        
        print(f"Generating {tfvar_file} from Excel...")
        tfvars_content = generate_tfvars_content(lb_row, provider_config)
        with open(tfvar_file, 'w') as f: f.write(tfvars_content)
        
        # Create workspace if it doesn't exist (for failed previous runs)
        if lb_name not in existing_workspaces:
            run_command(['terraform', 'workspace', 'new', lb_name])
        else:
            run_command(['terraform', 'workspace', 'select', lb_name])
            
        run_command(['terraform', 'apply', f'-var-file={tfvar_file}', '-auto-approve'])

def handle_destroy(df_lb: pd.DataFrame, provider_config: pd.Series):
    """Handles the Destroy action."""
    print_header("Destroy a Load Balancer")
    
    existing_workspaces = get_existing_workspaces(quiet=True)
    if existing_workspaces is None: return
    
    active_ws = sorted(list(existing_workspaces - {'default'}))
    if not active_ws:
        print("\nNo active deployments found to destroy.")
        return
        
    workspace_to_destroy = prompt_for_selection(active_ws, "Select a deployment to destroy:")
    if workspace_to_destroy is None: return

    tfvar_file = os.path.join(TFVARS_DIR, f"{workspace_to_destroy}.tfvars")
    run_command(['terraform', 'workspace', 'select', workspace_to_destroy])
    
    rc, _ = run_command(['terraform', 'destroy', f'-var-file={tfvar_file}', '-auto-approve'])
    if rc == 0:
        if input("Destroy successful. Delete workspace and .tfvars file? (y/n): ").lower() == 'y':
            run_command(['terraform', 'workspace', 'select', 'default'])
            run_command(['terraform', 'workspace', 'delete', workspace_to_destroy])
            if os.path.exists(tfvar_file): os.remove(tfvar_file)
            print(f"🧹 Workspace '{workspace_to_destroy}' and its .tfvars file removed.")

def handle_list_deployments(df_lb: pd.DataFrame, provider_config: pd.Series):
    """Handles the List Deployments action."""
    print_header("Deployment Status")
    
    print(f"{'Status':<15} {'Load Balancer Name':<30} {'Domains'}")
    print("-" * 70)
    for index, row in df_lb.iterrows():
        lb_name = row['lb_name']
        domains = row.get('domains', 'N/A')
        # Use the new, more accurate check for deployment status.
        status = "✅ Deployed" if is_deployed(lb_name) else "📝 Pending"
        print(f"{status:<15} {lb_name:<30} {domains}")

def handle_view_config(df_lb: pd.DataFrame, provider_config: pd.Series):
    """Handles the View Configuration action."""
    print_header("View Configuration from Excel")
    lb_rows = list(df_lb.itertuples(index=False))
    lb_row_to_view = prompt_for_selection(lb_rows, "Select an LB to view:", "lb_name")
    if lb_row_to_view is None: return
    display_config(lb_row_to_view)

def handle_plan(df_lb: pd.DataFrame, provider_config: pd.Series):
    """Handles the Check Deployment Status (Plan) action."""
    print_header("Check Deployment Status (Plan)")
    
    existing_workspaces = get_existing_workspaces(quiet=True)
    if existing_workspaces is None: return
    
    active_ws = sorted(list(existing_workspaces - {'default'}))
    if not active_ws:
        print("\nNo active deployments found to check."); return
        
    workspace_to_check = prompt_for_selection(active_ws, "Select a deployment to check:")
    if workspace_to_check is None: return

    tfvar_file = os.path.join(TFVARS_DIR, f"{workspace_to_check}.tfvars")
    run_command(['terraform', 'workspace', 'select', workspace_to_check])
    run_command(['terraform', 'plan', f'-var-file={tfvar_file}'])

def handle_refresh_tfvars(df_lb: pd.DataFrame, provider_config: pd.Series):
    """Handles the Refresh .tfvars File action."""
    print_header("Refresh .tfvars File from Excel")
    print("This will update a .tfvars file based on the Excel sheet without applying changes.")
    
    lb_rows = list(df_lb.itertuples(index=False))
    lb_row_to_refresh = prompt_for_selection(lb_rows, "Select an LB to refresh:", "lb_name")
    if lb_row_to_refresh is None: return

    lb_name = lb_row_to_refresh.lb_name
    tfvar_file = os.path.join(TFVARS_DIR, f"{lb_name}.tfvars")
    
    print(f"\nGenerating {tfvar_file} from the latest Excel data...")
    tfvars_content = generate_tfvars_content(lb_row_to_refresh, provider_config)
    with open(tfvar_file, 'w') as f: f.write(tfvars_content)
    print(f"✅ Successfully refreshed '{tfvar_file}'.")
    print("Run 'Check Status (Plan)' or 'Apply' to see or deploy the changes.")

def handle_export(df_lb: pd.DataFrame, provider_config: pd.Series):
    """Finds all deployed workspaces and exports their state and .tfvars files."""
    print_header("Export Deployments")
    
    existing_workspaces = get_existing_workspaces(quiet=True)
    if existing_workspaces is None: return

    active_ws = sorted(list(existing_workspaces - {'default'}))
    if not active_ws:
        print("No active deployments found to export."); return
        
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    zip_filename = f"deployments_export_{timestamp}.zip"
    
    print(f"The following {len(active_ws)} deployments will be exported to '{zip_filename}':")
    for ws_name in active_ws:
        print(f"  - {ws_name}")
        
    proceed = input("Do you want to proceed? (y/n): ").lower()
    if proceed != 'y':
        print("Export cancelled."); return

    try:
        with zipfile.ZipFile(zip_filename, 'w', zipfile.ZIP_DEFLATED) as zipf:
            print("\nExporting files...")
            for ws_name in active_ws:
                tfvar_file = os.path.join(TFVARS_DIR, f"{ws_name}.tfvars")
                if os.path.exists(tfvar_file):
                    zipf.write(tfvar_file, arcname=os.path.join(ws_name, f"{ws_name}.tfvars"))
                
                state_file_path = os.path.join('terraform.tfstate.d', ws_name, 'terraform.tfstate')
                if os.path.exists(state_file_path):
                    zipf.write(state_file_path, arcname=os.path.join(ws_name, 'terraform.tfstate'))
                else:
                    print(f"  - Warning: State file not found for workspace '{ws_name}' at {state_file_path}")

        print(f"\n✅ Successfully created export bundle: {zip_filename}")
    except Exception as e:
        print(f"\n❌ Failed to create export bundle. Error: {e}")


# ==============================================================================
# --- MAIN EXECUTION ---
# ==============================================================================

def main():
    """Main function to run the interactive orchestrator."""
    if not os.path.exists('.terraform'):
        print("Terraform project not initialized. Running `terraform init`...")
        if run_command(['terraform', 'init'])[0] != 0: sys.exit(1)
    
    menu_options = {
        '1': ("Apply a Single Deployment (Deploy or Modify)", handle_apply_single),
        '2': ("Apply All Pending Deployments", handle_apply_all),
        '3': ("Destroy a Load Balancer", handle_destroy),
        '4': ("List Deployments", handle_list_deployments),
        '5': ("View Configuration from Excel", handle_view_config),
        '6': ("Check Deployment Status (Plan)", handle_plan),
        '7': ("Refresh .tfvars File from Excel", handle_refresh_tfvars),
        '8': ("Export Deployments", handle_export),
        '9': ("Exit", lambda df, pc: sys.exit("👋 Exiting."))
    }

    while True:
        df_lb, provider_config = load_data()
        if df_lb is None:
            input("Please fix the Excel file and press Enter to try again...")
            continue
        print_header("F5 XC Terraform Orchestrator")
        for key, (description, _) in menu_options.items(): print(f"{key}. {description}")
        choice = input("Enter your choice: ")
        
        handler_tuple = menu_options.get(choice)
        if handler_tuple:
            handler_tuple[1](df_lb, provider_config)
        else:
            print("❌ Invalid choice, please try again.")
        
        if choice != '9':
            input("\nPress Enter to return to the main menu...")

if __name__ == "__main__":
    if not os.path.exists(TFVARS_DIR):
        print(f"✨ Directory '{TFVARS_DIR}' not found. Creating it for you.")
        os.makedirs(TFVARS_DIR)
    if not os.path.exists(MODULES_DIR):
         print(f"❌ Critical folder '{MODULES_DIR}' not found. Please ensure it exists.")
         sys.exit(1)
    main()

