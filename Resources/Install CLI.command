#!/bin/bash
# Move to the directory containing this script
cd "$(dirname "$0")"

echo "Installing sgnl CLI to $HOME/local/bin..."
mkdir -p "$HOME/local/bin"
cp sgnl "$HOME/local/bin/sgnl"
chmod +x "$HOME/local/bin/sgnl"

echo ""
echo "✓ sgnl has been installed to $HOME/local/bin/sgnl"
echo "Please ensure $HOME/local/bin is in your PATH."
echo "You can close this window now."
