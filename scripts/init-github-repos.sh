#!/bin/bash

# ============================================================================
# GitHub Repository Initialization Script
# Initializes git and pushes code to 6 separate GitHub repositories
# ============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration - UPDATE THESE WITH YOUR GITHUB USERNAME
GITHUB_USERNAME="${GITHUB_USERNAME:-YOUR-USERNAME}"

# Repository URLs
REPOS=(
  "iqq-infrastructure:https://github.com/${GITHUB_USERNAME}/iqq-infrastructure.git"
  "iqq-providers:https://github.com/${GITHUB_USERNAME}/iqq-providers.git"
  "iqq-lender-service:https://github.com/${GITHUB_USERNAME}/iqq-lender-service.git"
  "iqq-package-service:https://github.com/${GITHUB_USERNAME}/iqq-package-service.git"
  "iqq-product-service:https://github.com/${GITHUB_USERNAME}/iqq-product-service.git"
  "iqq-document-service:https://github.com/${GITHUB_USERNAME}/iqq-document-service.git"
)

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
  echo ""
  echo -e "${CYAN}========================================${NC}"
  echo -e "${CYAN}$1${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo ""
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

# ============================================================================
# Validation
# ============================================================================

validate_github_username() {
  if [ "$GITHUB_USERNAME" == "YOUR-USERNAME" ]; then
    print_error "Please set GITHUB_USERNAME environment variable"
    echo ""
    echo "Usage:"
    echo "  export GITHUB_USERNAME=your-github-username"
    echo "  ./scripts/init-github-repos.sh"
    echo ""
    exit 1
  fi
  
  print_success "GitHub username: ${GITHUB_USERNAME}"
}

check_git_installed() {
  if ! command -v git &> /dev/null; then
    print_error "git is not installed"
    exit 1
  fi
  print_success "git is installed"
}

# ============================================================================
# Repository Initialization
# ============================================================================

init_repository() {
  local dir=$1
  local remote_url=$2
  
  print_header "Initializing ${dir}"
  
  # Check if directory exists
  if [ ! -d "$dir" ]; then
    print_error "Directory ${dir} does not exist"
    return 1
  fi
  
  cd "$dir"
  
  # Initialize git if not already initialized
  if [ ! -d ".git" ]; then
    print_info "Initializing git repository..."
    git init
    print_success "Git initialized"
  else
    print_info "Git already initialized"
  fi
  
  # Add remote
  if git remote | grep -q "^origin$"; then
    print_info "Updating remote origin..."
    git remote set-url origin "$remote_url"
  else
    print_info "Adding remote origin..."
    git remote add origin "$remote_url"
  fi
  print_success "Remote added: ${remote_url}"
  
  # Add all files
  print_info "Adding files..."
  git add .
  
  # Check if there are changes to commit
  if git diff --staged --quiet; then
    print_warning "No changes to commit"
  else
    # Commit
    print_info "Creating initial commit..."
    git commit -m "Initial commit: ${dir} microservice

- Complete TypeScript implementation
- Unit tests with Jest
- SAM deployment configuration
- Comprehensive README
- .gitignore configured"
    print_success "Initial commit created"
  fi
  
  # Push to GitHub
  print_info "Pushing to GitHub..."
  if git push -u origin main 2>/dev/null; then
    print_success "Pushed to main branch"
  elif git push -u origin master 2>/dev/null; then
    print_success "Pushed to master branch"
  else
    print_warning "Push failed - you may need to create the repository first or authenticate"
    print_info "Repository URL: ${remote_url}"
  fi
  
  cd - > /dev/null
  echo ""
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
  print_header "GitHub Repository Initialization"
  
  # Validate prerequisites
  check_git_installed
  validate_github_username
  
  echo ""
  print_info "This script will initialize and push code to 6 GitHub repositories"
  print_warning "Make sure you have created the repositories on GitHub first!"
  echo ""
  
  read -p "Continue? (y/n) " -n 1 -r
  echo ""
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Aborted"
    exit 0
  fi
  
  # Initialize each repository
  for repo_config in "${REPOS[@]}"; do
    IFS=':' read -r dir remote_url <<< "$repo_config"
    init_repository "$dir" "$remote_url"
  done
  
  # Summary
  print_header "Summary"
  
  print_success "All repositories initialized!"
  echo ""
  print_info "Next steps:"
  echo "  1. Verify all repositories on GitHub"
  echo "  2. Update REPOSITORIES.md with actual URLs"
  echo "  3. Share repository links with your team"
  echo ""
  print_info "Repository URLs:"
  for repo_config in "${REPOS[@]}"; do
    IFS=':' read -r dir remote_url <<< "$repo_config"
    echo "  - ${remote_url}"
  done
  echo ""
}

# Run main function
main "$@"
