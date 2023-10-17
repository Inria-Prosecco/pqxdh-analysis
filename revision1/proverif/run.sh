#!/bin/bash
# Run the C preprocessor on the input file, produces a .pv file and runs proverif on it

res=""
name=""
for def in ${@:2}
do
    res+=" --define-macro=$def=$def"
name+="$def"
done
if [ "$name" = "" ]; then
  file="$1.gen.pv"
else	
  file="$1-$name.gen.pv" 
fi
eval "(
echo  \"(* !!! WARNING !!! *)\";
echo \"(* File generated from with ./run.sh $@*)\";
echo \"(* Read the README for more informations *)\";
echo \"(* ------------------------------------- *)\"; 
cpp -P -E -w $res $1.cpp.pv;
) > $file"
time proverif $file
