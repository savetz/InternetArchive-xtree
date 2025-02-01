#!/bin/sh
#show a tree of all the sub-collections and sub-sub collections under a collection.
#Kay Savetz, Dec 1 2023, released under MIT license https://opensource.org/licenses/MIT
#requires ia command line tool (https://archive.org/developers/quick-start-cli.html)
#v 0.2 look for subcollections also when collection doesn't have the base collection as an ancestor (@)
#v 0.3 works when the parent collection(s) is "null" or other non-array
#v 0.4 fixes borrowed collections (@)
#v 0.5 combine text and html output options into one script, with optional -html argument
#v 0.6 removed use of gnu parallel. It's slower now but more reliable: less likely to overwhelm IA's server

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 [-html] collection-identifier"
  exit 1
fi

HTML=0 

# Loop through all command-line arguments
for arg in "$@"; do
  # Check if the current argument is equal to "-html"
  if [ "$arg" == "-html" ]; then
    HTML=1
  fi
done

# The last argument is the collection-identifier
BASE="${!#}"

collection ()
{
    INDENT=$((INDENT+INTSPACES))
    COLS=$(ia search "collection:$1 AND mediatype:collection" -i)
    
    list=()
    for each in $COLS
    do
        TITLE=$(ia metadata $each | jq -r '.metadata.title' )
        list=("${list[@]}" "$TITLE~$each")
    done
    
    #sort by collection title
    IFS=$'\n' sorted=($(printf "%s\n" "${list[@]}" | sort -f))
    unset IFS

    for list in "${sorted[@]}"
    do
        TITLE=$(echo $list | awk -F~ '{print $1}')
        IDENTIFIER=$(echo $list | awk -F~ '{print $2}')
        if [[ "$TITLE" == *" Favorites"* ]]; then
            continue
        fi
        
        #show a collection if its primary collection is the displayed parent
        allcollections=$(ia metadata $IDENTIFIER | jq -r '.metadata.collection')
        if [[ "$allcollections" == *","* ]]; then #it's an array of collections
            parent=$(echo "$allcollections" | jq -r '.[0]') #get the 0th element, the primary collection
        else  #it's a string.
            parent=$(echo "$allcollections")
        fi
        
        if [[ "$parent" == "$1" ]]; then
            printf "%0.s$INTCHAR" $(seq 1 $INDENT)
            if [ "$HTML" -eq 1 ]; then
                echo "<a href=https://archive.org/details/$IDENTIFIER>$TITLE</a>"
            else
                echo "|$TITLE ($IDENTIFIER)"
            fi
            collection $IDENTIFIER
        else
            #...or if the collection doesn't have the base collection as an ancestor
            #I call these borrowed collections.
            #I will absolutely not understand this code in a week
            #If a borrowed collection is in 2+ collections under $BASE, only one will be shown. Sorry.
            HIT=0
            findparent $IDENTIFIER
            if [[ $HIT -eq 0 ]]; then
                #Identifier may be the child of potential parent ($1)
                #Now make sure it is really a child, not an grandchild
                #Get a list of all the sub-collections of the potential parent.
                #If identifier is in any of those sub-collections, skip this identifier: it is a (great?)grandchild, not a child


                newcollections=$(ia search "$1 AND mediatype:collection" -i | grep -v ^$1$)

                # Initialize TEST as an empty string
                TEST=""

                # Loop through newcollections and process each one
                for collection in $newcollections; do
                    #echo "Processing collection: $collection"

                    # Retry logic for transient errors
                    max_retries=10
                    attempt=1
                    while true; do
                        output=$(ia search "identifier:$IDENTIFIER AND collection:$collection" -i 2>error.log)
                        exit_code=$?

                        if [ $exit_code -eq 0 ]; then
                            # Command succeeded, append output to TEST
                            TEST+="$output"$'\n'
                            break
                        fi

                        # Check for the specific transient error
                        if grep -q "AttributeError: 'NoneType' object has no attribute 'get'" error.log; then
                            echo "Transient error detected. Retrying ($attempt/$max_retries)..."
                            attempt=$((attempt + 1))
                            if [ $attempt -gt $max_retries ]; then
                                echo "Maximum retries reached for collection: $collection. Skipping."
                                break
                            fi
                            sleep 5
                        else
                            #echo "Unexpected error occurred."
                            break
                        fi
                    done
                done

                # Check if TEST is empty
                if [ -z "$TEST" ]; then
                    # If no hits, it's a child of $1
                    printf "%0.s$INTCHAR" $(seq 1 $INDENT)
                    if [ "$HTML" -eq 1 ]; then
                        echo "<a href=https://archive.org/details/$IDENTIFIER>$TITLE@</a>"
                    else
                        echo "|$TITLE@ ($IDENTIFIER)"
                    fi
                    collection $IDENTIFIER
                fi

                
            fi
        fi
    done
    INDENT=$((INDENT-INTSPACES))
}

findparent()
{
        parent=$(ia metadata $1 | jq -r '.metadata.collection' )    
        if [[ "$parent" == *","* ]]; then #it's an array of collections
          parent=$(echo "$parent" | jq -r '.[0]') #get the 0th element, the primary collection
        #else  #it's a string.
        fi

        if [[ $parent == $BASE ]]; then #stop recursing and don't display this line
            HIT=1
        elif [[ $parent != "null" ]]; then
            findparent $parent
        fi
}

INDENT=0
TITLE=$(ia metadata $BASE | jq -r '.metadata.title')
if [ "$HTML" -eq 1 ]; then
    INTSPACES=1
    INTCHAR='*'
    echo "<a href=https://archive.org/details/$BASE>$TITLE</a>"
else
    INTSPACES=2
    INTCHAR=' '
    echo "$TITLE ($BASE)"
fi

collection $BASE
