#!/bin/bash
set -e

echo "=== Julia Setup for TeraFlow SDN ==="

# Always ensure julia is in PATH first (in case it was installed previously)
export PATH="$HOME/.juliaup/bin:$PATH"

# Check if Julia is already installed and working
JULIA_INSTALLED=false
if command -v julia >/dev/null 2>&1; then
    JULIA_VERSION=$(julia --version 2>/dev/null || echo "unknown")
    echo "[INFO] Julia already installed: $JULIA_VERSION"
    JULIA_INSTALLED=true
else
    echo "[INFO] Julia not found in PATH, checking for existing installation..."
    
    # Check if juliaup config exists but julia isn't working
    if [ -f "$HOME/.julia/juliaup/juliaup.json" ]; then
        echo "[INFO] Found existing juliaup config, cleaning up..."
        rm -rf "$HOME/.julia/juliaup/"
        echo "[INFO] Cleaned up old juliaup configuration"
    fi
fi

# Install Julia if not present using juliaup
if [ "$JULIA_INSTALLED" = false ]; then
    echo "[1/4] Installing Julia using juliaup..."
    
    # Install juliaup
    echo "Installing juliaup..."
    curl -fsSL https://install.julialang.org | sh -s -- --yes
    
    # Add juliaup to PATH for current session
    export PATH="$HOME/.juliaup/bin:$PATH"
    
    # Update shell profile to include juliaup in PATH for future sessions
    echo 'export PATH="$HOME/.juliaup/bin:$PATH"' >> ~/.bashrc
    
    echo "Julia installation complete"
    # Verify julia is now accessible
    if command -v julia >/dev/null 2>&1; then
        julia --version
    else
        echo "ERROR: Julia still not found in PATH after installation"
        exit 1
    fi
else
    echo "[1/4] Julia already installed ✓"
fi

# Setup Julia project
echo "[2/4] Setting up Julia project..."
cd $HOME/MINDFulTeraFlowSDN.jl

# Check if project is already instantiated and activate it
echo "Activating and instantiating Julia project..."
julia --project=. -e "using Pkg; Pkg.activate("."); Pkg.instantiate()"

CONFIG_PATH="${CONFIG_PATH:-test/data/config3.toml}"
julia --project=. -e "push!(ARGS, "${CONFIG_PATH}"); push!(ARGS, "127.0.0.1"); using MINDFulTeraFlowSDN; MINDFulTeraFlowSDN.main()" 

# Run TeraFlow setup
# echo "[3/4] Checking TeraFlow contexts and topology..."
# JULIA_OUTPUT=$(julia --project=. -e "
# using MINDFulTeraFlowSDN

# try
#     # Initialize SDN controller (same as in the actual code)
#     sdncontroller = TeraflowSDN()
    
#     # Target IDs
#     target_topology_uuid = \"c76135e3-24a8-5e92-9bed-c3c9139359c8\"
#     admin_context_uuid = stable_uuid(999999, :admin_context)
    
#     println(\"DEBUG: Using API URL: \$(sdncontroller.api_url)\")
#     println(\"DEBUG: Looking for admin_context_uuid: \$admin_context_uuid\")
#     println(\"DEBUG: Looking for target_topology_uuid: \$target_topology_uuid\")
    
#     # Check contexts (using same pattern as actual code)
#     contexts_response = get_contexts(sdncontroller.api_url)
#     println(\"DEBUG: Got contexts response with keys: \$(keys(contexts_response))\")
    
#     admin_context_exists = false
#     target_topology_exists = false
    
#     if haskey(contexts_response, \"contexts\")
#         contexts = contexts_response[\"contexts\"]
#         println(\"DEBUG: Found \$(length(contexts)) contexts\")
        
#         for context in contexts
#             context_uuid = context[\"context_id\"][\"context_uuid\"][\"uuid\"]
#             context_name = get(context, \"name\", \"Unknown\")
#             println(\"DEBUG: Checking context: \$context_name (UUID: \$context_uuid)\")
            
#             if context_uuid == admin_context_uuid && context_name == \"admin\"
#                 admin_context_exists = true
#                 println(\"DEBUG: Found matching admin context!\")
                
#                 # Check topology in this context (using same pattern as actual code)
#                 try
#                     topologies_response = get_topologies(sdncontroller.api_url, context_uuid)
#                     println(\"DEBUG: Got topologies response with keys: \$(keys(topologies_response))\")
                    
#                     if haskey(topologies_response, \"topologies\")
#                         topologies = topologies_response[\"topologies\"]
#                         println(\"DEBUG: Found \$(length(topologies)) topologies\")
                        
#                         for topology in topologies
#                             topology_uuid = topology[\"topology_id\"][\"topology_uuid\"][\"uuid\"]
#                             topology_name = get(topology, \"name\", \"Unknown\")
#                             println(\"DEBUG: Checking topology: \$topology_name (UUID: \$topology_uuid)\")
                            
#                             if topology_uuid == target_topology_uuid
#                                 target_topology_exists = true
#                                 println(\"DEBUG: Found matching target topology!\")
#                                 break
#                             end
#                         end
#                     end
#                 catch e
#                     println(\"DEBUG: Error checking topologies: \$e\")
#                 end
#                 break
#             end
#         end
#     else
#         println(\"DEBUG: No 'contexts' key found in response\")
#     end
    
#     println(\"DEBUG: admin_context_exists = \$admin_context_exists\")
#     println(\"DEBUG: target_topology_exists = \$target_topology_exists\")
    
#     # Print result
#     if admin_context_exists && target_topology_exists
#         println(\"SKIP\")
#     else
#         println(\"NEEDED\")
#     end
# catch e
#     println(\"DEBUG: Caught error: \$e\")
#     println(\"NEEDED\")
# end
# ")

# # Extract only the last line (the actual result)
# SETUP_NEEDED=$(echo "$JULIA_OUTPUT" | tail -n 1)

# echo "Setup check result: $SETUP_NEEDED"

# if [ "$SETUP_NEEDED" = "SKIP" ]; then
#     echo "✓ Admin context and target topology admin already exist - skipping setup"
# else
#     echo "Setting up TeraFlow contexts and topology..."
#     julia --project=. -e "using MINDFulTeraFlowSDN; setup_context_topology()"
# fi

# echo "[4/4] Creating graph and devices in TeraFlow..."
# julia --project=. -e "using MINDFulTeraFlowSDN; create_graph_with_devices()"

# echo "Verifying TeraFlow deployment..."
# julia --project=. -e "using MINDFulTeraFlowSDN; verify_tfs_deployment()"

# echo "=== Julia Setup Complete ==="