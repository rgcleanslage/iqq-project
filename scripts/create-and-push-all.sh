#!/bin/bash

# ============================================================================
# GitHub CLI - Complete Repository Creation and Push Script
# Creates all 6 repositories and pushes code automatically
# Compatible with bash 3.2+ (macOS default)
# ============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
VISIBILITY="${REPO_VISIBILITY:-private}"  # private or public

# Repository definitions (name|description|topics)
REPOS=(
  "iqq-infrastructure|Terraform infrastructure for iQQ Insurance Quoting Platform|terraform aws infrastructure iac api-gateway cognito dynamodb step-functions"
  "iqq-providers|Provider integration services with adapters and OAuth authorizer|aws lambda typescript provider-integration oauth api-gateway-authorizer"
  "iqq-lender-service|Lender microservice for iQQ platform|aws lambda typescript microservice serverless sam"
  "iqq-package-service|Package microservice with Step Functions orchestration|aws lambda typescript microservice serverless sam step-functions"
  "iqq-product-service|Product microservice for iQQ platform|aws lambda typescript microservice serverless sam"
  "iqq-document-service|Document microservice for iQQ platform|aws lambda typescript microservice serverless sam"
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

check_gh_installed() {
  if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed"
    echo ""
    echo "Install with:"
    echo "  macOS:   brew install gh"
    echo "  Linux:   See https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    echo "  Windows: See https://github.com/cli/cli/releases"
    echo ""
    exit 1
  fi
  print_success "GitHub CLI is installed"
}

check_gh_auth() {
  if ! gh auth status &> /dev/null; then
    print_error "Not authenticated with GitHub"
    echo ""
    echo "Please run:"
    echo "  gh auth login"
    echo ""
    echo "Then run this script again."
    exit 1
  fi
  print_success "Authenticated with GitHub"
  
  # Get username
  GITHUB_USERNAME=$(gh api user -q .login)
  print_info "GitHub username: ${GITHUB_USERNAME}"
}

check_git_installed() {
  if ! command -v git &> /dev/null; then
    print_error "git is not installed"
    exit 1
  fi
  print_success "git is installed"
}

# ============================================================================
# Repository Creation
# ============================================================================

create_repository() {
  local repo_name=$1
  local description=$2
  local topics=$3
  
  print_info "Creating repository: ${repo_name}"
  
  # Check if repository already exists
  if gh repo view "${GITHUB_USERNAME}/${repo_name}" &> /dev/null; then
    print_warning "Repository ${repo_name} already exists, skipping creation"
    return 0
  fi
  
  # Create repository (without --source flag)
  if gh repo create "${GITHUB_USERNAME}/${repo_name}" \
    --${VISIBILITY} \
    --description "${description}"; then
    print_success "Created repository: ${repo_name}"
    
    # Add topics
    if [ -n "$topics" ]; then
      print_info "Adding topics..."
      gh repo edit "${GITHUB_USERNAME}/${repo_name}" --add-topic ${topics} 2>/dev/null || true
      print_success "Topics added"
    fi
    
    return 0
  else
    print_error "Failed to create repository: ${repo_name}"
    return 1
  fi
}

# ============================================================================
# Git Operations
# ============================================================================

init_and_push() {
  local dir=$1
  local repo_name=$2
  
  print_header "Pushing ${repo_name}"
  
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
  
  # Set default branch to main
  git branch -M main 2>/dev/null || git checkout -b main 2>/dev/null || true
  
  # Add remote if not exists
  if ! git remote | grep -q "^origin$"; then
    print_info "Adding remote origin..."
    git remote add origin "https://github.com/${GITHUB_USERNAME}/${repo_name}.git"
    print_success "Remote added"
  else
    print_info "Remote origin already exists, updating URL..."
    git remote set-url origin "https://github.com/${GITHUB_USERNAME}/${repo_name}.git"
  fi
  
  # Add all files
  print_info "Adding files..."
  git add .
  
  # Check if there are changes to commit
  if git diff --staged --quiet; then
    print_warning "No changes to commit"
  else
    # Commit
    print_info "Creating initial commit..."
    git commit -m "Initial commit: ${repo_name}

- Complete implementation
- Comprehensive documentation
- Tests and deployment configuration
- Ready for deployment"
    print_success "Initial commit created"
  fi
  
  # Push to GitHub
  print_info "Pushing to GitHub..."
  if git push -u origin main; then
    print_success "Pushed to GitHub"
  else
    print_error "Push failed"
    cd - > /dev/null
    return 1
  fi
  
  cd - > /dev/null
  echo ""
  return 0
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
  print_header "GitHub CLI - Complete Setup"
  
  # Validate prerequisites
  check_gh_installed
  check_git_installed
  check_gh_auth
  
  echo ""
  print_info "Repository visibility: ${VISIBILITY}"
  print_info "Number of repositories: ${#REPOS[@]}"
  echo ""
  
  # Confirm
  print_warning "This will create ${#REPOS[@]} repositories and push code"
  echo ""
  echo "Press 'y' to continue, any other key to abort..."
  read -n 1 -r
  echo ""
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Aborted"
    exit 0
  fi
  
  # Track success/failure
  CREATED_REPOS=""
  FAILED_REPOS=""
  SUCCESS_COUNT=0
  FAILED_COUNT=0
  
  # Process each repository
  for repo_config in "${REPOS[@]}"; do
    # Parse config (name|description|topics)
    IFS='|' read -r repo_name description topics <<< "$repo_config"
    
    print_header "Processing: ${repo_name}"
    
    # Create repository on GitHub
    if create_repository "$repo_name" "$description" "$topics"; then
      # Initialize and push code
      if init_and_push "$repo_name" "$repo_name"; then
        CREATED_REPOS="${CREATED_REPOS}${repo_name}\n"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      else
        FAILED_REPOS="${FAILED_REPOS}${repo_name}\n"
        FAILED_COUNT=$((FAILED_COUNT + 1))
      fi
    else
      FAILED_REPOS="${FAILED_REPOS}${repo_name}\n"
      FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
  done
  
  # Summary
  print_header "Summary"
  
  echo -e "${GREEN}Successfully created and pushed: ${SUCCESS_COUNT}${NC}"
  if [ -n "$CREATED_REPOS" ]; then
    echo -e "$CREATED_REPOS" | while read -r repo; do
      if [ -n "$repo" ]; then
        echo -e "  ${GREEN}✓${NC} https://github.com/${GITHUB_USERNAME}/${repo}"
      fi
    done
  fi
  
  if [ $FAILED_COUNT -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed: ${FAILED_COUNT}${NC}"
    if [ -n "$FAILED_REPOS" ]; then
      echo -e "$FAILED_REPOS" | while read -r repo; do
        if [ -n "$repo" ]; then
          echo -e "  ${RED}✗${NC} ${repo}"
        fi
      done
    fi
  fi
  
  echo ""
  print_success "All done!"
  echo ""
  print_info "Next steps:"
  echo "  1. Visit your repositories on GitHub"
  echo "  2. Verify all files are present"
  echo "  3. Update REPOSITORIES.md with actual URLs"
  echo "  4. Start deploying!"
  echo ""
  print_info "View all repositories:"
  echo "  gh repo list"
  echo ""
}

# Run main function
main "$@"
