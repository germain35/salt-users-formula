{%- from "users/map.jinja" import users with context %}

include:
  - users.install
  {%- if users.sudo_enabled %}
  - users.sudo
  {%- endif %}
  - users.users