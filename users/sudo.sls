# vim: sts=2 ts=2 sw=2 et ai
{% from "users/map.jinja" import users with context %}

include:
  - users.install

users_{{ users.sudoers_dir }}:
  file.directory:
    - name: {{ users.sudoers_dir }}

users_sudoers_defaults:
  file.append:
    - name: {{ users.sudoers_file }} 
    - text:
      - Defaults   env_reset
      - Defaults   secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      - '#includedir {{ users.sudoers_dir }}'
    - require:
      - pkg: users_sudo_package


