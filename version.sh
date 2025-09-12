#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get current version from git tags
get_current_version() {
    local latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    echo "${latest_tag#v}"
}

# Get next version based on type
get_next_version() {
    local current_version=$1
    local version_type=$2
    
    # Parse version components
    IFS='.' read -r major minor patch <<< "$current_version"
    
    case $version_type in
        major)
            echo "$((major + 1)).0.0"
            ;;
        minor)
            echo "$major.$((minor + 1)).0"
            ;;
        patch)
            echo "$major.$minor.$((patch + 1))"
            ;;
        *)
            print_error "Invalid version type: $version_type"
            print_error "Valid types: major, minor, patch"
            exit 1
            ;;
    esac
}

# Validate version format
validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid version format: $version"
        print_error "Version must be in format: X.Y.Z (e.g., 1.0.0)"
        exit 1
    fi
}

# Update version in files
update_version_files() {
    local version=$1
    
    print_status "Updating version in files..."
    
    # Update package.json if it exists
    if [ -f "package.json" ]; then
        sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$version\"/" package.json
        print_success "Updated package.json"
    fi
    
    # Update Dockerfile labels if they exist
    if [ -f "liquibase-migrator/Dockerfile" ]; then
        # Add or update version label
        if grep -q "LABEL version=" liquibase-migrator/Dockerfile; then
            sed -i "s/LABEL version=\"[^\"]*\"/LABEL version=\"$version\"/" liquibase-migrator/Dockerfile
        else
            sed -i "/FROM liquibase\/liquibase:latest/a LABEL version=\"$version\"" liquibase-migrator/Dockerfile
        fi
        print_success "Updated Dockerfile"
    fi
    
    # Create or update VERSION file
    echo "$version" > VERSION
    print_success "Updated VERSION file"
}

# Create git tag
create_git_tag() {
    local version=$1
    local tag="v$version"
    
    print_status "Creating git tag: $tag"
    
    # Check if tag already exists
    if git tag -l | grep -q "^$tag$"; then
        print_warning "Tag $tag already exists"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git tag -d "$tag" 2>/dev/null || true
            git push origin ":refs/tags/$tag" 2>/dev/null || true
        else
            print_error "Aborted"
            exit 1
        fi
    fi
    
    git tag -a "$tag" -m "Release version $version"
    print_success "Created git tag: $tag"
}

# Push changes and tags
push_changes() {
    local version=$1
    local tag="v$version"
    
    print_status "Pushing changes to remote..."
    
    # Add modified files
    git add VERSION
    [ -f "package.json" ] && git add package.json
    [ -f "liquibase-migrator/Dockerfile" ] && git add liquibase-migrator/Dockerfile
    
    # Commit changes
    git commit -m "Bump version to $version" || print_warning "No changes to commit"
    
    # Push commits
    git push origin HEAD
    
    # Push tags
    git push origin "$tag"
    
    print_success "Pushed changes and tag to remote"
}

# Show current version
show_version() {
    local current_version=$(get_current_version)
    print_status "Current version: $current_version"
}

# Show help
show_help() {
    echo "Version Management Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  current                 Show current version"
    echo "  bump <type>            Bump version (major|minor|patch)"
    echo "  set <version>          Set specific version"
    echo "  release <type>         Bump version and create release"
    echo "  help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 current             # Show current version"
    echo "  $0 bump patch          # Bump patch version (0.1.0 -> 0.1.1)"
    echo "  $0 bump minor          # Bump minor version (0.1.0 -> 0.2.0)"
    echo "  $0 bump major          # Bump major version (0.1.0 -> 1.0.0)"
    echo "  $0 set 1.2.3           # Set version to 1.2.3"
    echo "  $0 release patch       # Bump patch and create release"
}

# Main function
main() {
    case "${1:-}" in
        current)
            show_version
            ;;
        bump)
            if [ -z "${2:-}" ]; then
                print_error "Version type required (major|minor|patch)"
                exit 1
            fi
            
            local current_version=$(get_current_version)
            local next_version=$(get_next_version "$current_version" "$2")
            
            print_status "Current version: $current_version"
            print_status "Next version: $next_version"
            
            update_version_files "$next_version"
            create_git_tag "$next_version"
            push_changes "$next_version"
            
            print_success "Version bumped to $next_version"
            ;;
        set)
            if [ -z "${2:-}" ]; then
                print_error "Version required"
                exit 1
            fi
            
            validate_version "$2"
            
            print_status "Setting version to $2"
            update_version_files "$2"
            create_git_tag "$2"
            push_changes "$2"
            
            print_success "Version set to $2"
            ;;
        release)
            if [ -z "${2:-}" ]; then
                print_error "Version type required (major|minor|patch)"
                exit 1
            fi
            
            local current_version=$(get_current_version)
            local next_version=$(get_next_version "$current_version" "$2")
            
            print_status "Creating release $next_version"
            update_version_files "$next_version"
            create_git_tag "$next_version"
            push_changes "$next_version"
            
            print_success "Release $next_version created and pushed"
            print_status "GitHub Actions will now build and publish the release"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: ${1:-}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
