# Clean Arch system with a normal user, to imitate a fresh install.
# Built and used by tests/run.sh: you don't need to build it by hand.

FROM archlinux:latest

# The base image is minimal: add what the tests (and debugging) need.
#   diffutils -> diff, to compare installed files with the repo
#   tree      -> handy when exploring with `tests/run.sh --shell`
RUN pacman -Syu --noconfirm diffutils tree which \
	&& pacman -Scc --noconfirm

# A regular user with an empty home, like on a new machine.
RUN useradd -m tester
USER tester
WORKDIR /home/tester

CMD ["bash"]
