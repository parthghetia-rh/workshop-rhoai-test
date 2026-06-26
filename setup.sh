#!/bin/bash
echo "Setting up workspace..."

# 1. Install Python dependencies
pip install -r requirements.txt

# 2. Download the latest stable Continue extension (v1.2.22) directly from GitHub Releases
echo "Downloading the latest Continue extension backup..."
wget -q -nc https://github.com/continuedev/continue/releases/download/v1.2.22-vscode/continue-linux-x64-1.2.22.vsix -O continue-offline.vsix

# 3. Create the Continue.dev configuration directory
mkdir -p ~/.continue

# 4. Inject the configuration file to point to your internal GPU pod
cat <<EOF > ~/.continue/config.json
{
  "models": [
    {
      "title": "granite-8b-code-instruct",
      "provider": "openai",
      "model": "granite-8b-code-instruct",
      "apiBase": "https://granite-8b-code-instruct.workshop-maas.svc.cluster.local/v1",
      "apiKey": "dummy-key",
      "contextLength": 4096,
      "completionOptions": {
        "maxTokens": 1024
      }
    }
  ],
  "tabAutocompleteModel": {
    "title": "Workshop Autocomplete",
    "provider": "openai",
    "model": "granite-8b-code-instruct",
    "apiBase": "https://granite-8b-code-instruct.workshop-maas.svc.cluster.local/v1",
    "apiKey": "dummy-key",
    "contextLength": 4096,
    "completionOptions": {
      "maxTokens": 256
    }
  },
  "allowAnonymousTelemetry": false
}
EOF

echo "Workspace setup complete!"