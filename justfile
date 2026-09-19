set dotenv-load := true
export ANSIBLE_CONFIG := "ansible/ansible.cfg"

default:
    @just --list

build:
    cd zig && zig build -Doptimize=ReleaseFast

run:
    cd zig && zig build run

check:
    cd zig && zig fmt --check src/

format:
    cd zig && zig fmt src/

host-setup:
    ansible-playbook -i ansible/hosts.ini ansible/site.yml

awg-mesh:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/awg_mesh.yml

bootstrap:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/bootstrap.yml

hypervisors:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/hypervisors.yml

control-plane:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/control_plane.yml

backups:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/backups.yml

observability:
    ansible-playbook -i ansible/hosts.ini ansible/playbooks/observability.yml
