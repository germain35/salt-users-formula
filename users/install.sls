{%- from "users/map.jinja" import users with context %}

{%- if users.sudo_enabled %}
users_sudo_package:
  pkg.installed:
    - name: {{ users.sudo_pacakge }}
{%- endif %}

{%- if users.bash_enabled %}
users_bash_package:
  pkg.installed:
    - name: {{ users.bash_pacakge }}
{%- endif %}