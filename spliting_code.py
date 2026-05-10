import json 
import os

input_file="data set path"
output_prefix="split_file_"
num_files=10

with open(input_file,"r",encoding="utf8") as f:
    total_lines=sum(1 for _ in f)

lines_per_file=total_lines//num_files

output_dir="output path"
os.makedirs(output_dir, exist_ok=True)


with open(input_file,"r",encoding="utf8") as f:
    for i in range(num_files):
        output_filename=f"{output_dir}{output_prefix}{i+1}.json"

        with open(output_filename,"w",encoding="utf8") as out_file:
            for j in range(lines_per_file):
                line=f.readline()
                if not line:
                    break
                out_file.write(line)
print("splitting complete")

