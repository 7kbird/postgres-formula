{% from "postgres/map.jinja" import postgres with context %}
{% import_yaml "postgres/defaults.yaml" as defaults %}

{% set dockers  = salt['pillar.get']('postgres:dockers', default={}) %}

{% for name in dockers %}
{% set docker = salt['pillar.get']('postgres:dockers:' ~ name,
                                  default=defaults.docker,
                                  merge=True) %}

{% set conf_dir = docker.get('conf_dir', postgres.docker_dir_root ~ '/' ~ name) %}
postgres-docker_conf_dir_{{ name }}:
  file.directory:
    - name: {{ conf_dir }}
    - makedirs: True
    - unless: test -f {{ conf_dir }}/PG_VERSION

postgres-docker-running_{{ name }}:
  dockerng.running:
    - name: {{ name }}
    - image: {{ docker.image }}
    - ports:
      - {{ docker.port }}
    - environment: {{ docker.environment }}
    - binds: {{ docker.get('binds', conf_dir ~ ':' ~  postgres.conf_dir) }}

pg_hba.conf_docker_{{ name }}:
  file.blockreplace:
    - name: {{ conf_dir }}/pg_hba.conf
    - source: {{ postgres['pg_hba.conf'] }}
    - template: jinja
    - defaults:
        acls: {{ docker.acls }}
    - prepend_if_not_found: True
    - backup: '.bak'
    - show_changes: True
    - require:
      - file: postgres-docker_conf_dir_{{ name }}
    - watch_in:  # TODO: some docker will change pg_hba.conf and this file cannot be managed
      - dockerng: postgres-docker-running_{{ name }}

{% if name not in salt['dockerng.list_containers']()  %}
docker-not-found:
  test.fail_without_changes:
    - name: 'docker is not started, postgres cannot connect yet,please retry later'
{% else %}
{% set docker_ip = salt['dockerng.inspect_container'](name).NetworkSettings.IPAddress %}

{% for user_name, user in docker.users.items() %}
postgres-docker-{{ name }}-user-{{ user_name }}:
{% if user.get('ensure', 'present') == 'present' %}
  postgres_user.present:
    - name: {{ user_name }}
    - createdb: {{ user.get('createdb', False) }}
    - createroles: {{ user.get('createroles', False) }}
    - createuser: {{ user.get('createuser', False) }}
    - inherit: {{ user.get('inherit', True) }}
    - replication: {{ user.get('replication', False) }}
    - password: {{ user.get('password', 'changethis') }}
    #- user: {{ user.get('runas', 'postgres') }}
    - superuser: {{ user.get('superuser', False) }}
    - db_host: {{ docker_ip }}
    - db_port: {{ docker.port }}
    - db_user: {{ docker.db_user }}
    - db_password: {{ docker.db_password }}
    - require:
      - dockerng: postgres-docker-running_{{ name }}
{% else %}
  postgres_user.absent:
    - name: {{ user_name }}
    - user: {{ user.get('runas', 'postgres') }}
    - db_host: {{ docker_ip }}
    - db_port: {{ docker.port }}
    - db_user: {{ docker.db_user }}
    - db_password: {{ docker.db_password }}
    - require:
      - dockerng: postgres-docker-running_{{ name }}
{% endif %}
{% endfor %}

{% for db_name, db in docker.databases.items() %}
postgres-db-{{ db_name }}:
  postgres_database.present:
    - name: {{ db_name }}
    - encoding: {{ db.get('encoding', '') }}
    - lc_ctype: {{ db.get('lc_ctype', '') }}
    - lc_collate: {{ db.get('lc_collate', '') }}
    - template: {{ db.get('template', '') }}
    - owner: {{ db.get('owner', '') }}
    - user: {{ db.get('runas', '') }}
    - db_host: {{ docker_ip }}
    - db_user: {{ docker.db_user }}
    - db_password: {{ docker.db_password }}
    - require:
      - dockerng: postgres-docker-running_{{ name }}
      {% if db.get('user') %}
      - postgres_user: postgres-docker-{{ name }}-user-{{ db.get('user') }}
      {% endif %}

# TODO: schema
{% endfor %}


{% endif %} # wait for docker start

{% endfor %}
