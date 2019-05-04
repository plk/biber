DEL_FLAG="false"

while getopts ":d" opt; do
  case $opt in
    d)
      DEL_FLAG="true";;
  esac
done
shift $((OPTIND -1))

if [ -z "$1" ]
  then
    echo "No search path"
    exit 1
fi

for file in `find $1 -name \*.so`; do
  if `readelf -d $file | grep -q RPATH`; then
     if [[ "$DEL_FLAG" == "true" ]]; then
       echo "remove RPATH from $file"
       chrpath -d $file
     else
       echo "$file"
     fi
  fi
done
