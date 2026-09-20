set dotenv-load := true
export ANSIBLE_CONFIG := "ansible/ansible.cfg"

default:
    @just --list

build:
    cd zig && zig build -Doptimize=ReleaseFast
    cd cli && zig build -Doptimize=ReleaseFast

build-server:
    cd zig && zig build -Doptimize=ReleaseFast

build-cli:
    cd cli && zig build -Doptimize=ReleaseFast

run:
    cd zig && zig build run

check:
    cd zig && zig fmt --check src/
    cd cli && zig fmt --check src/

format:
    cd zig && zig fmt src/
    cd cli && zig fmt src/

host-setup:
    ansible-playbook -i ansible/hosts.ini ansible/site.yml

bootstrap:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/bootstrap.yml

hypervisors:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/hypervisors.yml

observability:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/observability.yml
