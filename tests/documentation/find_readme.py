import os
import argparse

#  Usage: python3 find_readme.py --dir ~/Projects/forked/GenAIComps > readme_list.txt

def find_readme(root_dir="."):
    """Finds README.md files within the specified directory, searching recursively."""
    readme_files = []
    for root, _, files in os.walk(root_dir):
        for file in files:
            if file.lower() == "readme.md":
                readme_files.append(os.path.join(root, file))
    return readme_files


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Find README files.")
    parser.add_argument("--dir", type=str, default=".", help="Directory to search for READMEs")
    parser.add_argument("--debug", action="store_true", help="Enable debug mode")

    args = parser.parse_args()

    results = find_readme(args.dir)
    if results:
        if args.debug:
            for readme_file in results:
                print(f"README: {readme_file}")
        else:
            for readme_file in results:
                print(readme_file)
    else:
        print("No READMEs found.")