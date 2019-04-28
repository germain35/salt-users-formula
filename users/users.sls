{%- from "users/map.jinja" import users with context %}

include:
  - users.install
  - users.sudo

{% macro useradd(user, params) -%}
# group
#####################################################################

  {%- if params.group is defined and params.group.get('name', False) %}
    {%- set user_group = params.group.name %}
  {%- else %}
    {%- set user_group = user %}
  {%- endif %}
users_{{ user }}_group:
  group.present:
    - name: {{ user_group }}
    {%- if params.group is defined and params.group.gid is defined %}
    - gid: {{ params.group.gid }}
    {%- elif params.uid is defined %}
    - gid: {{ params.uid }}
    {%- endif %}
    {%- if params.system is defined  and params.system %}
    - system: True
    {%- endif %}
    - require_in:
      - user: {{ user }}


# user
#####################################################################
  {%- if user == 'root' %}
    {%- set user_home = '/root' %}
  {%- else %}
    {%- set user_home = params.get('home', '/home' | path_join(user)) %}
  {%- endif %}

{{ user }}:
  user.present:
    - home: {{ user_home }}
    - shell: {{ params.get('shell', '/bin/bash') }}
    {%- if params.uid is defined %}
    - uid: {{ params.uid }}
    {%- endif %}
    {%- if params.get('allow_uid_change', False) %}
    - allow_uid_change: True
    {%- endif %}
    {%- if params.password is defined %}
    - password: '{{ params.password }}'
    {%- endif %}
    {%- if params.get('empty_password', False) %}
    - empty_password: True
    {%- endif %}
    {%- if params.get('enforce_password', True) %}
    - enforce_password: True
    {%- else %}
    - enforce_password: False
    {%- endif %}
    {%- if params.get('hash_password', False) %}
    - hash_password: True
    {%- else %}
    - hash_password: False
    {%- endif %}
    {%- if params.get('system', False) %}
    - system: True
    {%- endif %}
    {%- if params.group is defined and (params.group.get('gid', False) or params.group.get('name', False)) %}
    - gid: {{ params.get('gid', params.group.get('name', user)) }}
    {%- else %}
      {%- set user_group = user %}
    - gid_from_name: True
    {%- endif -%}
    {%- if params.get('allow_gid_change', False) %}
    - allow_gid_change: True
    {%- endif %}
    {%- if params.fullname is defined %}
    - fullname: {{ params.fullname }}
    {%- endif %}
    {%- if params.roomnumber is defined %}
    - roomnumber: {{ params.roomnumber }}
    {%- endif %}
    {%- if params.workphone is defined %}
    - workphone: {{ params.workphone }}
    {%- endif %}
    {%- if params.homephone is defined %}
    - homephone: {{ params.homephone }}
    {%- endif %}
    - createhome: {{ params.get('createhome', True) }}
    {%- if params.expire is defined %}
      {%- if grains['kernel'].endswith('BSD') and
          user['expire'] < 157766400 %}
        {# 157762800s since epoch equals 01 Jan 1975 00:00:00 UTC #}
    - expire: {{ params.expire * 86400 }}
      {%- elif grains['kernel'] == 'Linux' and
          user['expire'] > 84006 %}
        {# 2932896 days since epoch equals 9999-12-31 #}
    - expire: {{ (params.expire / 86400) | int}}
      {%- else %}
    - expire: {{ params.expire }}
      {%- endif %}
    {%- endif %}
    - remove_groups: {{ params.get('remove_groups', 'True') }}
    {%- if params.groups is defined %}
    - groups: {{ params.groups }}
    {%- endif %}
    {%- if params.optional_groups is defined %}
    - optional_groups: {{ params.optional_groups }}
    {%- endif %}
    {%- if params.require is defined %}
    - require: {{ params.require }}
    {%- endif %}


# ssh
#####################################################################

  {%- if params.ssh is defined %}

    {%- set user_ssh_dir = user_home | path_join(users.ssh_key_dir) %}
users_{{ user }}_ssh_dir:
  file.directory:
    - name: {{ user_ssh_dir }}
    - user: {{ user }}
    - group: {{ user_group }}
    - mode: 700
    - makedirs: True
    - require:
      - user: {{ user }}

    {%- if params.ssh.config is defined %}
users_{{ user }}_ssh_config:
  file.managed:
    - name: {{ user_ssh_dir }}/config
    - user: {{ user }}
    - group: {{ user_group }}
    - mode: 640
    - contents: |
        # Managed by Saltstack
        # Do Not Edit
        {% for label, setting in params.ssh.config.items() %}
        # {{ label }}
        Host {{ setting.get('hostname') }}
          {%- for opts in setting.get('options') %}
          {{ opts }}
          {%- endfor %}
        {%- endfor %}
    - require:
      - file: users_{{ user }}_ssh_dir
    {%- endif %}

    {%- if 'keys' in params.ssh %}
      {%- for ssh_key, ssh_key_params in params.ssh.get('keys', {}).items() %}
        {%- if ssh_key_params is mapping %}
          {%- if ssh_key_params.get('private', False) %}
users_{{ user }}_ssh_{{ ssh_key }}_private_key:
  file.managed:
    {%- if ssh_key == 'default' %}
    - name: {{ user_ssh_dir | path_join('id_' ~ ssh_key_params.get('enc', 'rsa')) }}
    {%- else %}
    - name: {{ user_ssh_dir | path_join('id_' ~ ssh_key_params.get('enc', 'rsa') ~ '_' ~ ssh_key) }}
    {%- endif %}
    - contents: |
        {{ ssh_key_params.private | indent(8) }}
    - user: {{ user }}
    - group: {{ user_group }}
    - mode: 600
    - show_diff: False
    - makedirs: True
    - require:
      - file: users_{{ user }}_ssh_dir
          {%- endif %}
          {%- if ssh_key_params.get('public', False) %}
users_{{ user }}_ssh_{{ ssh_key }}_public_key:
  file.managed:
    {%- if ssh_key == 'default' %}
    - name: {{ user_ssh_dir | path_join('id_' ~ ssh_key_params.get('enc', 'rsa') ~ '.pub') }}
    {%- else %}
    - name: {{ user_ssh_dir | path_join('id_' ~ ssh_key_params.get('enc', 'rsa') ~ '_' ~ ssh_key ~ '.pub') }}
    {%- endif %}
    - contents: |
        {{ ssh_key_params.public | indent(8) }}
    - user: {{ user }}
    - group: {{ user_group }}
    - mode: 644
    - show_diff: False
    - makedirs: True
    - require:
      - file: users_{{ user }}_ssh_dir
          {%- endif %}
        {%- else %}
          {%- if ssh_key == 'private' %}
users_{{ user }}_ssh_{{ ssh_key }}_private_key:
  file.managed:
    - name: {{ user_ssh_dir | path_join('id_' ~ params.ssh.get('keys').get('enc', 'rsa')) }}
    - contents: |
        {{ ssh_key_params | indent(8) }}
    - user: {{ user }}
    - group: {{ user_group }}
    - mode: 600
    - show_diff: False
    - makedirs: True
    - require:
      - file: users_{{ user }}_ssh_dir
          {%- elif ssh_key == 'public' %}
users_{{ user }}_ssh_{{ ssh_key }}_public_key:
  file.managed:
    - name: {{ user_ssh_dir | path_join('id_' ~ params.ssh.get('keys').get('enc', 'rsa') ~ '.pub') }}
    - contents: |
        {{ ssh_key_params | indent(8) }}
    - user: {{ user }}
    - group: {{ user_group }}
    - mode: 644
    - show_diff: False
    - makedirs: True
    - require:
      - file: users_{{ user }}_ssh_dir
          {%- endif %}
        {%- endif %}
      {%- endfor %}
    {%- endif %}

    {% if params.ssh.auth is defined %}
      {%- if params.ssh.auth.purge is defined and params.ssh.auth.purge %}
users_{{ user }}_ssh_auth_purge:
  file.absent:
    - name: {{ user_home | path_join(users.ssh_auth_conf_file) }}
    - require:
      - user: {{ user }}
      {%- endif %}

      {%- if 'keys' in params.ssh.auth %}
users_{{ user }}_ssh_auth:
  file.managed:
    - name: {{ user_home | path_join(users.ssh_auth_conf_file) }}
    - user: {{ user }}
    - group: {{ user_group }}
    - mode: 600
    - replace: False
  ssh_auth.present:
    - names: {{  params.ssh.auth.get('keys', []) }}
      {%- if params.ssh.auth.enc is defined %}
    - enc: {{ params.ssh.auth.enc }}
      {%- endif %}
    - user: {{ user }}
    - require:
      - user: {{ user }}
      {%- endif %}

    {%- endif %}

    {% if params.ssh.known_hosts is defined %}
      {%- if params.ssh.known_hosts.purge is defined and params.ssh.known_hosts.purge %}
users_{{ user }}_ssh_knwon_hosts_purge:
  file.absent:
    - name: {{ user_home | path_join(users.ssh_known_hosts_conf_file) }}
    - require:
      - user: {{ user }}
      {%- endif %}

      {%- if params.ssh.known_hosts.hosts is defined %}
users_{{ user }}_ssh_knwon_hosts:
  file.managed:
    - name: {{ user_home | path_join(users.ssh_known_hosts_conf_file) }}
    - user: {{ user }}
    - group: {{ user_group }}
    - mode: 600
    - replace: False

        {%- for k, v in params.ssh.known_hosts.hosts.items() %}
users_{{ user }}_ssh_knwon_hosts_{{ loop.index0 }}:
  ssh_known_hosts.present:
    - name: {{ k }}
    - user: {{ user }}
    {%- if v.key is defined %}
    - key: {{ v.key }}
      {%- if v.enc is defined %}
    - enc: {{ v.enc }}
      {%- endif %}
    {%- elif v.fingerprint is defined %}
    - fingerprint: {{ v.fingerprint }}
    {%- endif %}
    - require:
      - file: users_{{ user }}_ssh_knwon_hosts
        {%- endfor %}

      {%- endif %}
    {%- endif %}

  {%- endif %}



# sudo
#####################################################################

  {%- if users.sudo_enabled and params.sudo is defined %}

users_sudoer_{{ user }}:
  file.managed:
    - replace: False
    - name: {{ users.sudoers_dir }}/{{ user }}
    - user: root
    - group: {{ users.root_group }}
    - mode: '0440'

    {%- if params.sudo.rules is defined %}
      {%- for rule in params.sudo.rules %}
"validate {{ user }} sudo rule {{ loop.index0 }} {{ user }} {{ rule }}":
  cmd.run:
    - name: 'visudo -cf - <<<"$rule" | { read output; if [[ $output != "stdin: parsed OK" ]] ; then echo $output ; fi }'
    - stateful: True
    - shell: {{ users.visudo_shell }}
    - env:
      # Specify the rule via an env var to avoid shell quoting issues.
      - rule: "{{ user }} {{ rule }}"
    - require:
      - file: users_sudoer_{{ user }}
    - require_in:
      - file: users_{{ users.sudoers_dir }}/{{ user }}
      {%- endfor %}

      {%- if params.sudo.defaults is defined %}
        {%- for entry in params.sudo.defaults %}
"validate {{ user }} sudo Defaults {{ loop.index0 }} {{ user }} {{ entry }}":
  cmd.run:
    - name: 'visudo -cf - <<<"$rule" | { read output; if [[ $output != "stdin: parsed OK" ]] ; then echo $output ; fi }'
    - stateful: True
    - shell: {{ users.visudo_shell }}
    - env:
      # Specify the rule via an env var to avoid shell quoting issues.
      - rule: "Defaults:{{ user }} {{ entry }}"
    - require_in:
      - file: users_{{ users.sudoers_dir }}/{{ user }}
        {%- endfor %}
      {%- endif %}

users_{{ users.sudoers_dir }}/{{ user }}:
  file.managed:
    - replace: True
    - name: {{ users.sudoers_dir }}/{{ user }}
    - contents: |
      {%- if params.sudo.defaults is defined %}
        {%- for entry in params.sudo.defaults %}
        Defaults:{{ user }} {{ entry }}
        {%- endfor %}
      {%- endif %}
        ########################################################################
        # File managed by Salt (users-formula).
        # Your changes will be overwritten.
        ########################################################################
        #
      {%- for rule in params.sudo.rules %}
        {{ user }} {{ rule }}
      {%- endfor %}
    - require:
      - file: users_sudoer_defaults
      - file: users_sudoer_{{ user }}
  cmd.wait:
    - name: visudo -cf {{ users.sudoers_dir }}/{{ user }} || ( rm -rvf {{ users.sudoers_dir }}/{{ user }}; exit 1 )
    - watch:
      - file: {{ users.sudoers_dir }}/{{ user }}

    {%- endif %}

  {%- else %}

users_{{ users.sudoers_dir }}/{{ user }}:
  file.absent:
    - name: {{ users.sudoers_dir }}/{{ user }}

  {%- endif %}
{%- endmacro %}


# remove users
#####################################################################

{%- for user, params in users.get('absent', {}).items() %}
users_user_{{ user }}_absent:
  user.absent:
    - name: {{ user }}
    {%- if params.purge is defined %}
    - purge: {{ params.purge }}
    {%- endif %}
    {%- if params.force is defined %}
    - force: {{ params.force }}
    {%- endif %}
{%- endfor %}


# add users
#####################################################################

# --- creates users with fixed uid/gid
{%- for user, params in users.get('present', {}).items() %}
  {%- set intersect =  params.keys() | intersect(['uid', 'gid']) %}
  {%- if intersect|length > 0 %}
{{useradd(user, params)}}
  {%- endif %}
{%- endfor %}

# --- creates users without uid/gid
{%- for user, params in users.get('present', {}).items() %}
  {%- set intersect =  params.keys() | intersect(['uid', 'gid']) %}
  {%- if intersect|length == 0 %}
{{useradd(user, params)}}
  {%- endif %}
{%- endfor %}
