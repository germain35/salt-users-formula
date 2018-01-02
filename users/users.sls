
{%- from "users/map.jinja" import users with context %}

include:
  - users.install
  - users.sudo

{%- for user, params in users.get('present', {}).iteritems() %}

# group
##################################################################### 

  {%- if params.goup is defined and params.goup.name is defined %}
    {%- set user_group = params.goup.name %}
users_{{ user }}_group:
  group.present:
    - name: {{ params.goup.name }}
    {%- if params.goup.gid is defined %}
    - gid: {{ params.goup.gid }}
    {%- elif params.uid is defined %}
    - gid: {{ params.uid }}
    {%- endif %}
    {%- if params.system is defined  and params.system %}
    - system: True
    {%- endif %}
    - require_in:
      - user: {{ user }}
  {%- endif %}


# user
##################################################################### 
{{ user }}:
  user.present:
    - home: {{ home }}
    - shell: {{ params.get('shell', '/bin/bash'))) }}
    {%- if params.uid is defined %}
    - uid: {{ params.uid }}
    {%- endif %}
    {%- if params.password is defined %}
    - password: '{{ params.password }}'
    {%- endif %}
    {% if params.empty_password is defined -%}
    - empty_password: {{ params.empty_password }}
    {%- endif %}
    {%- if params.enforce_password is defined %}
    - enforce_password: {{ params.enforce_password }}
    {%- endif %}
    {% if params.hash_password is defined -%}
    - hash_password: {{ params.hash_password }}
    {%- endif %}
    {%- if params.get('system', False) %}
    - system: True
    {%- endif %}
    {%- if params.group is defined and (params.group.gid is defined or params.group.name is defined) %}
    - gid: {{ params.get('gid', params.group.name) }}
    {%- else %}
      {%- set user_group = user %}
    - gid_from_name: True
    {% endif -%}
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


# ssh
#####################################################################

  {% if params.ssh is defined %}
    {%- set user_ssh_dir = params.get('home', '/home') | path_join(users.ssh_key_dir)) %}
users_{{ user }}_ssh_dir:
  file.directory:
    - name: {{ user_ssh_dir }}
    - user: {{ user }}
    - group: {{ user_group }}
    - mode: 700
    - makedirs: True
    - require:
      - user: {{ user }}

    {% if params.ssh.config is defined %}
users_{{ user }}_ssh_config:
  file.managed:
    - name: {{ user_ssh_dir }}/config
    - user: {{ name }}
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
        {% endfor -%}
    - require:
      - file: users_{{ user }}_ssh_dir
    {%- endif %}

    {% if params.ssh.key is defined %}
      {%- if params.ssh.keys.private is defined %}
users_{{ user }}_ssh_private_key:
  file.managed:
    - name: {{ user_ssh_dir | path_join('id_' ~ params.ssh.key.get('enc', 'rsa')) }}
    - content: {{ params.ssh.key.private }}
    - user: {{ user }}
    - group: {{ user_group }}
    - mode: 600
    - show_diff: False
    - makedirs: True
    - require:
      - file: users_{{ user }}_ssh_dir
      {%- endif %}
      {%- if params.ssh.key.private is defined %}
users_{{ user }}_ssh_public_key:
  file.managed:
    - name: {{ user_ssh_dir | path_join('id_' ~ params.ssh.key.get('enc', 'rsa') ~ '.pub') }}
    - content: {{ params.ssh.key.private }}
    - user: {{ user }}
    - group: {{ user_group }}
    - mode: 644
    - show_diff: False
    - makedirs: True
    - require:
      - file: users_{{ user }}_ssh_dir
      {%- endif %}
    {%- endif %}

    {% if params.ssh.auth is defined %}
      {%- if params.ssh.auth.purge is defined and params.ssh.auth.purge %}
users_{{ user }}_ssh_auth_purge:
  file.absent:
    - name: {{ params.get('home', '/home') | path_join(user, users.ssh_auth_conf_file)) }}
    - require:
      - user: {{ user }}
      {%- endif %}

      {%- if params.ssh.auth.keys is defined %}
users_{{ user }}_ssh_auth:
  file.present:
    - name: {{ params.get('home', '/home') | path_join(user, users.ssh_auth_conf_file)) }}
    - user: {{ user }}
    - group: {{ user_group }}
    - mode: 600
  ssh_auth.present:
    - names: {{ params.ssh.auth.keys }}
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
    - name: {{ params.get('home', '/home') | path_join(user, users.ssh_known_hosts_conf_file)) }}
    - require:
      - user: {{ user }}
    {%- endif %}
    
    {%- if params.ssh.known_hosts.hosts is defined %}
users_{{ user }}_ssh_knwon_hosts:
  file.present:
    - name: {{ params.get('home', '/home') | path_join(user, users.ssh_known_hosts_conf_file)) }}
    - user: {{ user }}
    - group: {{ user_group }}
    - mode: 600
    
      {%- for k, v in params.ssh.known_hosts.hosts.iteritems() %}
users_{{ user }}_ssh_knwon_hosts_{{ loop.index0 }}:
  ssh_known_hosts.present:
    - name: {{ k }}
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

{%- endfor %}


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


# remove users
#####################################################################

{%- for user, params in users.get('absent', {}).iteritems() %}
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
