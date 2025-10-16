#!/usr/bin/env python3
"""
Quick fixes for common deployment issues
"""

import os
import re

def fix_port_configuration():
    """Ensure bot uses PORT environment variable"""
    with open('pouchon_bot.py', 'r') as f:
        content = f.read()
    
    # Check if PORT is already configured
    if 'os.getenv("PORT"' in content or "os.getenv('PORT'" in content:
        print("✅ PORT configuration already correct")
        return True
    
    # Find uvicorn configuration and fix it
    if 'uvicorn.Config' in content:
        new_content = re.sub(
            r'uvicorn\.Config\([^)]+port=[^,)]+[^)]*\)',
            'uvicorn.Config(app, host="0.0.0.0", port=int(os.getenv("PORT", 8000)), log_level="info")',
            content
        )
        
        if new_content != content:
            with open('pouchon_bot.py', 'w') as f:
                f.write(new_content)
            print("✅ Fixed PORT configuration")
            return True
        else:
            print("❌ Could not auto-fix PORT configuration")
            return False
    else:
        print("❌ No uvicorn configuration found")
        return False

def check_requirements():
    """Check and suggest missing requirements"""
    required_packages = {
        'fastapi': 'fastapi',
        'uvicorn': 'uvicorn', 
        'python-telegram-bot': 'python-telegram-bot',
        'aiosqlite': 'aiosqlite',
        'httpx': 'httpx',
        'paystackapi': 'paystackapi',
        'python-dotenv': 'python-dotenv'
    }
    
    if not os.path.exists('requirements.txt'):
        print("❌ requirements.txt not found")
        return False
        
    with open('requirements.txt', 'r') as f:
        current_reqs = f.read().lower()
    
    missing = []
    for pkg, req_name in required_packages.items():
        if req_name.lower() not in current_reqs:
            missing.append(req_name)
    
    if missing:
        print(f"⚠️  Suggested additions to requirements.txt:")
        for pkg in missing:
            print(f"   {pkg}")
        return False
    else:
        print("✅ requirements.txt looks good")
        return True

def main():
    print("🔧 Running deployment issue fixes...\n")
    
    fixes = [
        fix_port_configuration,
        check_requirements
    ]
    
    for fix in fixes:
        fix()
        print()

if __name__ == "__main__":
    main()
