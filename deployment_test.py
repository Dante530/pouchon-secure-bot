#!/usr/bin/env python3
"""
Telegram Bot Deployment Readiness Test
Tests if pouchon_bot.py is ready for Railway deployment
"""

import os
import sys
import subprocess
import importlib.util
import ast
import re
from pathlib import Path

class DeploymentTester:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.bot_file = "pouchon_bot.py"
        self.requirements_file = "requirements.txt"
        
    def print_status(self, test_name, status, message=""):
        """Print test status with colors"""
        colors = {
            "SUCCESS": "✅",
            "ERROR": "❌", 
            "WARNING": "⚠️",
            "INFO": "ℹ️"
        }
        print(f"{colors.get(status, '')} {test_name}: {message}")
        
    def test_file_exists(self):
        """Test if main bot file exists"""
        if os.path.exists(self.bot_file):
            self.print_status("Bot file exists", "SUCCESS", f"Found {self.bot_file}")
            return True
        else:
            self.print_status("Bot file exists", "ERROR", f"Missing {self.bot_file}")
            self.errors.append(f"Missing {self.bot_file}")
            return False
            
    def test_requirements_exists(self):
        """Test if requirements.txt exists"""
        if os.path.exists(self.requirements_file):
            self.print_status("Requirements file", "SUCCESS", f"Found {self.requirements_file}")
            return True
        else:
            self.print_status("Requirements file", "ERROR", f"Missing {self.requirements_file}")
            self.errors.append(f"Missing {self.requirements_file}")
            return False
            
    def test_python_syntax(self):
        """Test Python syntax of bot file"""
        try:
            with open(self.bot_file, 'r', encoding='utf-8') as f:
                source_code = f.read()
            ast.parse(source_code)
            self.print_status("Python syntax", "SUCCESS", "Valid Python syntax")
            return True
        except SyntaxError as e:
            self.print_status("Python syntax", "ERROR", f"Syntax error: {e}")
            self.errors.append(f"Python syntax error: {e}")
            return False
            
    def test_imports_availability(self):
        """Test if all imports are available"""
        try:
            with open(self.bot_file, 'r', encoding='utf-8') as f:
                source_code = f.read()
                
            # Extract imports using AST
            tree = ast.parse(source_code)
            imports = []
            
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        imports.append(alias.name)
                elif isinstance(node, ast.ImportFrom):
                    module = node.module
                    for alias in node.names:
                        imports.append(f"{module}.{alias.name}")
            
            # Test each import
            missing_imports = []
            for imp in set(imports):
                try:
                    # Handle submodule imports
                    base_module = imp.split('.')[0]
                    if base_module not in ['os', 'sys', 'asyncio', 'typing', 'datetime', 'hmac', 'hashlib']:
                        importlib.import_module(base_module)
                except ImportError as e:
                    missing_imports.append(imp)
                    
            if not missing_imports:
                self.print_status("Import dependencies", "SUCCESS", "All imports available")
                return True
            else:
                self.print_status("Import dependencies", "ERROR", f"Missing: {', '.join(missing_imports)}")
                self.errors.append(f"Missing imports: {', '.join(missing_imports)}")
                return False
                
        except Exception as e:
            self.print_status("Import dependencies", "ERROR", f"Check failed: {e}")
            self.errors.append(f"Import check failed: {e}")
            return False
            
    def test_requirements_completeness(self):
        """Test if requirements.txt covers all imports"""
        try:
            # Read requirements
            with open(self.requirements_file, 'r') as f:
                requirements = [line.strip().split('==')[0].split('>=')[0] for line in f if line.strip()]
            
            # Get imports from bot file
            with open(self.bot_file, 'r', encoding='utf-8') as f:
                source_code = f.read()
                
            tree = ast.parse(source_code)
            imports = set()
            
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        imports.add(alias.name.split('.')[0])
                elif isinstance(node, ast.ImportFrom):
                    if node.module:
                        imports.add(node.module.split('.')[0])
            
            # Filter out stdlib modules
            stdlib_modules = {'os', 'sys', 'asyncio', 'typing', 'datetime', 'hmac', 'hashlib', 're', 'json', 'time'}
            external_imports = imports - stdlib_modules
            
            # Check coverage
            missing_in_requirements = []
            for imp in external_imports:
                if imp.lower() not in [req.lower() for req in requirements]:
                    missing_in_requirements.append(imp)
            
            if not missing_in_requirements:
                self.print_status("Requirements coverage", "SUCCESS", "All imports covered in requirements.txt")
                return True
            else:
                self.print_status("Requirements coverage", "WARNING", f"Add to requirements: {', '.join(missing_in_requirements)}")
                self.warnings.append(f"Missing in requirements: {', '.join(missing_in_requirements)}")
                return False
                
        except Exception as e:
            self.print_status("Requirements coverage", "ERROR", f"Check failed: {e}")
            self.errors.append(f"Requirements check failed: {e}")
            return False
            
    def test_environment_variables(self):
        """Test for required environment variables"""
        try:
            with open(self.bot_file, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Find os.getenv calls
            env_pattern = r'os\.getenv\([\'"]([^\'"]+)[\'"]'
            env_vars = set(re.findall(env_pattern, content))
            
            required_vars = {var for var in env_vars if var not in ['PORT']}  # PORT is provided by Railway
            
            if required_vars:
                self.print_status("Environment variables", "INFO", f"Required: {', '.join(required_vars)}")
                return True
            else:
                self.print_status("Environment variables", "WARNING", "No environment variables detected")
                return True
                
        except Exception as e:
            self.print_status("Environment variables", "ERROR", f"Check failed: {e}")
            return False
            
    def test_webhook_configuration(self):
        """Test webhook configuration"""
        try:
            with open(self.bot_file, 'r', encoding='utf-8') as f:
                content = f.read()
                
            has_webhook = "WEBHOOK_URL" in content or "webhook" in content.lower()
            has_fastapi = "FastAPI" in content or "from fastapi" in content
            
            if has_webhook and has_fastapi:
                self.print_status("Webhook setup", "SUCCESS", "FastAPI webhook configured")
                return True
            else:
                self.print_status("Webhook setup", "WARNING", "Webhook setup may need verification")
                return True
                
        except Exception as e:
            self.print_status("Webhook setup", "ERROR", f"Check failed: {e}")
            return False
            
    def test_port_configuration(self):
        """Test PORT environment variable usage"""
        try:
            with open(self.bot_file, 'r', encoding='utf-8') as f:
                content = f.read()
                
            if "os.getenv(\"PORT\"" in content or "os.getenv('PORT'" in content:
                self.print_status("PORT configuration", "SUCCESS", "Using PORT environment variable")
                return True
            else:
                self.print_status("PORT configuration", "ERROR", "Not using PORT env variable - required for Railway")
                self.errors.append("Bot must use PORT environment variable for Railway")
                return False
                
        except Exception as e:
            self.print_status("PORT configuration", "ERROR", f"Check failed: {e}")
            return False
            
    def test_database_paths(self):
        """Test for absolute paths that might break on Railway"""
        try:
            with open(self.bot_file, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Look for potential absolute path issues
            suspicious_paths = re.findall(r'[\'"]/\w+[/\w]*[\'"]', content)
            home_paths = re.findall(r'[\'"]~/[\w/]*[\'"]', content)
            
            if suspicious_paths or home_paths:
                self.print_status("Path configuration", "WARNING", f"Check paths: {suspicious_paths + home_paths}")
                self.warnings.append(f"Potential path issues: {suspicious_paths + home_paths}")
                return False
            else:
                self.print_status("Path configuration", "SUCCESS", "No suspicious absolute paths")
                return True
                
        except Exception as e:
            self.print_status("Path configuration", "ERROR", f"Check failed: {e}")
            return False

    def run_all_tests(self):
        """Run all deployment readiness tests"""
        print("🚀 Running Telegram Bot Deployment Readiness Tests...\n")
        
        tests = [
            self.test_file_exists,
            self.test_requirements_exists,
            self.test_python_syntax,
            self.test_imports_availability,
            self.test_requirements_completeness,
            self.test_environment_variables,
            self.test_webhook_configuration,
            self.test_port_configuration,
            self.test_database_paths
        ]
        
        for test in tests:
            test()
            
        # Summary
        print("\n" + "="*50)
        print("📊 DEPLOYMENT READINESS SUMMARY")
        print("="*50)
        
        if self.errors:
            print(f"❌ CRITICAL ERRORS ({len(self.errors)}):")
            for error in self.errors:
                print(f"   • {error}")
            print(f"\n💡 Your bot will likely CRASH on Railway!")
        else:
            print("✅ No critical errors found!")
            
        if self.warnings:
            print(f"\n⚠️  WARNINGS ({len(self.warnings)}):")
            for warning in self.warnings:
                print(f"   • {warning}")
            print(f"\n💡 These should be fixed for optimal performance")
        else:
            print("✅ No warnings!")
            
        if not self.errors:
            print(f"\n🎉 Your bot is READY for Railway deployment!")
            print("Next steps:")
            print("1. Set environment variables on Railway")
            print("2. Connect your GitHub repository")
            print("3. Deploy!")
        else:
            print(f"\n🔧 Fix the errors above before deploying to Railway!")
            
        return len(self.errors) == 0

if __name__ == "__main__":
    tester = DeploymentTester()
    success = tester.run_all_tests()
    sys.exit(0 if success else 1)
