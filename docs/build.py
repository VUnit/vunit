from subprocess import check_call
from os.path import dirname
import sys
from create_release_notes import create_release_notes

def main():
    create_release_notes()
    check_call([sys.executable, "-m", "sphinx",
                "-T", "-E", "-W", "-a", "-n", "-b", "html",
                dirname(__file__), sys.argv[1]])

if __name__ == "__main__":
    main()
