{% from "postgres/map.jinja" import dockers with context %}
{% from "postgres/map.jinja" import postgres  with context %}


{% for name, docker in dockers.items() %}

{% if docker.conf_dir is defined %}
  {% set conf_dir = docker.conf_dir %}
{% else %}
  {% set conf_dir = postgres.docker_dir_root ~ '/' ~ name %}
{% endif %}
postgres-docker_conf_dir_{{ name }}:
  file.directory:
    - name: {{ conf_dir }}
    - makedirs: True
    - unless: test -f {{ conf_dir }}/PG_VERSION

postgres-docker-running_{{ name }}:
  dockerng.running:
    - name: {{ name }}
    - image: {{ docker.image }}
{% if 'binds' in docker %}
    - binds: {{ docker.binds }}
{% else %}
    - binds: {{ conf_dir }}:{{ postgres.conf_dir }}
{% endif %}

pg_hba.conf_docker_{{ name }}:
  file.managed:
    - name: {{ conf_dir }}/pg_hba.conf
    - source: {{ postgres['pg_hba.conf'] }}
    - template: jinja
    - defaults:
        acls: {{ docker.acls if 'acls' in docker else {} }}
    - mode: 644
    - require:
      - file: postgres-docker_conf_dir_{{ name }}
    - watch_in:
      - docker: postgres-docker-running_{{ name }}

{% endfor %}








