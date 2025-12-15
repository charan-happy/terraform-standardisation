#!/bin/bash
# Terraform state management commands
# CAUTION: These commands modify state directly - always backup first!

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🗂️  Terraform State Management${NC}"
echo "================================"
echo ""

# Function to backup state
backup_state() {
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_FILE="state-backup-${TIMESTAMP}.tfstate"
    
    echo -e "${YELLOW}📦 Backing up state...${NC}"
    terraform state pull > "$BACKUP_FILE"
    
    if [ -f "$BACKUP_FILE" ]; then
        echo -e "${GREEN}✅ State backed up to: $BACKUP_FILE${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}❌ Backup failed!${NC}"
        exit 1
    fi
}

# Show usage
usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  list                      List all resources in state"
    echo "  show <resource>           Show details of a specific resource"
    echo "  mv <from> <to>           Rename a resource in state"
    echo "  rm <resource>            Remove a resource from state (doesn't delete from AWS)"
    echo "  import <addr> <id>       Import existing AWS resource"
    echo "  pull                     Pull remote state to local file"
    echo "  push <file>              Push local state to remote (DANGEROUS)"
    echo "  backup                   Create state backup"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 show module.web_server.aws_instance.main[0]"
    echo "  $0 mv aws_instance.old aws_instance.new"
    echo "  $0 rm aws_instance.legacy"
    echo "  $0 import aws_instance.existing i-0abc123"
    exit 1
}

# Check if command provided
if [ $# -eq 0 ]; then
    usage
fi

COMMAND=$1
shift

case "$COMMAND" in
    list)
        echo "📋 Listing all resources in state:"
        echo ""
        terraform state list
        echo ""
        RESOURCE_COUNT=$(terraform state list | wc -l)
        echo -e "${GREEN}Total: $RESOURCE_COUNT resources${NC}"
        ;;
        
    show)
        if [ $# -eq 0 ]; then
            echo -e "${RED}Error: Resource address required${NC}"
            echo "Usage: $0 show <resource>"
            exit 1
        fi
        
        RESOURCE=$1
        echo "🔍 Showing resource: $RESOURCE"
        echo ""
        terraform state show "$RESOURCE"
        ;;
        
    mv)
        if [ $# -lt 2 ]; then
            echo -e "${RED}Error: Source and destination required${NC}"
            echo "Usage: $0 mv <from> <to>"
            exit 1
        fi
        
        FROM=$1
        TO=$2
        
        backup_state
        
        echo -e "${YELLOW}🔄 Moving resource in state:${NC}"
        echo "  From: $FROM"
        echo "  To:   $TO"
        echo ""
        
        read -p "Continue? (yes/no): " CONFIRM
        if [ "$CONFIRM" = "yes" ]; then
            terraform state mv "$FROM" "$TO"
            echo -e "${GREEN}✅ Resource moved successfully${NC}"
        else
            echo -e "${YELLOW}❌ Operation cancelled${NC}"
        fi
        ;;
        
    rm)
        if [ $# -eq 0 ]; then
            echo -e "${RED}Error: Resource address required${NC}"
            echo "Usage: $0 rm <resource>"
            exit 1
        fi
        
        RESOURCE=$1
        
        backup_state
        
        echo -e "${RED}⚠️  WARNING: This will remove resource from state${NC}"
        echo -e "${YELLOW}The resource will still exist in AWS!${NC}"
        echo ""
        echo "Resource: $RESOURCE"
        echo ""
        
        read -p "Are you sure? (yes/no): " CONFIRM
        if [ "$CONFIRM" = "yes" ]; then
            terraform state rm "$RESOURCE"
            echo -e "${GREEN}✅ Resource removed from state${NC}"
            echo -e "${YELLOW}Remember: Resource still exists in AWS${NC}"
        else
            echo -e "${YELLOW}❌ Operation cancelled${NC}"
        fi
        ;;
        
    import)
        if [ $# -lt 2 ]; then
            echo -e "${RED}Error: Resource address and ID required${NC}"
            echo "Usage: $0 import <address> <id>"
            exit 1
        fi
        
        ADDRESS=$1
        ID=$2
        
        echo -e "${YELLOW}📥 Importing resource:${NC}"
        echo "  Address: $ADDRESS"
        echo "  ID:      $ID"
        echo ""
        
        terraform import "$ADDRESS" "$ID"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Import successful${NC}"
            echo ""
            echo "Next steps:"
            echo "  1. Add resource configuration to your .tf files"
            echo "  2. Run: terraform plan"
            echo "  3. Adjust configuration until plan shows no changes"
        fi
        ;;
        
    pull)
        FILENAME="terraform-state-$(date +%Y%m%d-%H%M%S).tfstate"
        
        echo "📥 Pulling remote state to local file..."
        terraform state pull > "$FILENAME"
        
        if [ -f "$FILENAME" ]; then
            echo -e "${GREEN}✅ State saved to: $FILENAME${NC}"
            
            # Show stats
            RESOURCE_COUNT=$(cat "$FILENAME" | jq '.resources | length')
            echo ""
            echo "State statistics:"
            echo "  Resources: $RESOURCE_COUNT"
            echo "  Size: $(ls -lh "$FILENAME" | awk '{print $5}')"
        fi
        ;;
        
    push)
        if [ $# -eq 0 ]; then
            echo -e "${RED}Error: State file required${NC}"
            echo "Usage: $0 push <file>"
            exit 1
        fi
        
        STATEFILE=$1
        
        if [ ! -f "$STATEFILE" ]; then
            echo -e "${RED}Error: File not found: $STATEFILE${NC}"
            exit 1
        fi
        
        backup_state
        
        echo -e "${RED}⚠️  DANGER: This will replace remote state!${NC}"
        echo -e "${YELLOW}Make sure you know what you're doing!${NC}"
        echo ""
        echo "State file: $STATEFILE"
        echo ""
        
        read -p "Are you ABSOLUTELY sure? (type 'yes' to confirm): " CONFIRM
        if [ "$CONFIRM" = "yes" ]; then
            cat "$STATEFILE" | terraform state push -
            echo -e "${GREEN}✅ State pushed${NC}"
        else
            echo -e "${YELLOW}❌ Operation cancelled${NC}"
        fi
        ;;
        
    backup)
        backup_state
        echo "💾 Backup complete"
        ;;
        
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        echo ""
        usage
        ;;
esac
