#!/bin/bash

# Hikari Documentation Development Script

set -e

cd "$(dirname "$0")/docs"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js 18+ to continue."
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    print_error "Node.js version 18+ is required. Current version: $(node -v)"
    exit 1
fi

print_status "Node.js version: $(node -v) ✓"

# Function to show help
show_help() {
    echo "Hikari Documentation Development Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  install, i    Install dependencies"
    echo "  start, dev    Start development server"
    echo "  build, b      Build for production"
    echo "  serve, s      Serve built site locally"
    echo "  clean, c      Clean build files and cache"
    echo "  check         Check for issues"
    echo "  help, h       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 install    # Install dependencies"
    echo "  $0 start      # Start development server"
    echo "  $0 build      # Build for production"
}

# Function to install dependencies
install_deps() {
    print_status "Installing dependencies..."
    npm ci
    print_success "Dependencies installed successfully!"
}

# Function to start development server
start_dev() {
    print_status "Starting development server..."
    print_status "The site will open at: http://localhost:3000/hikari-go/"
    print_warning "Press Ctrl+C to stop the server"
    npm start
}

# Function to build for production
build_prod() {
    print_status "Building for production..."
    npm run build
    print_success "Build completed! Files are in the 'build' directory."
}

# Function to serve built site
serve_site() {
    print_status "Serving built site..."
    if [ ! -d "build" ]; then
        print_warning "Build directory not found. Running build first..."
        build_prod
    fi
    print_status "Site will be available at: http://localhost:3000/"
    npm run serve
}

# Function to clean files
clean_files() {
    print_status "Cleaning build files and cache..."
    npm run clear
    rm -rf build .docusaurus node_modules/.cache
    print_success "Cleaned successfully!"
}

# Function to check for issues
check_issues() {
    print_status "Checking for common issues..."
    
    # Check for missing files
    if [ ! -f "package.json" ]; then
        print_error "package.json not found!"
        exit 1
    fi
    
    if [ ! -f "docusaurus.config.ts" ]; then
        print_error "docusaurus.config.ts not found!"
        exit 1
    fi
    
    if [ ! -d "docs" ]; then
        print_error "docs directory not found!"
        exit 1
    fi
    
    # Check for node_modules
    if [ ! -d "node_modules" ]; then
        print_warning "node_modules not found. Run '$0 install' first."
    fi
    
    print_success "Basic checks passed!"
}

# Main script logic
case "${1:-}" in
    install|i)
        install_deps
        ;;
    start|dev)
        if [ ! -d "node_modules" ]; then
            print_warning "Dependencies not found. Installing..."
            install_deps
        fi
        start_dev
        ;;
    build|b)
        if [ ! -d "node_modules" ]; then
            print_warning "Dependencies not found. Installing..."
            install_deps
        fi
        build_prod
        ;;
    serve|s)
        serve_site
        ;;
    clean|c)
        clean_files
        ;;
    check)
        check_issues
        ;;
    help|h)
        show_help
        ;;
    *)
        print_error "Unknown command: ${1:-}"
        echo ""
        show_help
        exit 1
        ;;
esac
