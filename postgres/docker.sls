{% from "postgres/map.jinja" import dockers with context %}

{% for name, docker in dockers.items() %}
postgresql-docker-running_{{ name }}:
  dockerng.running:
    - name: {{ name }}
    - image: {{ docker.image }}
{% endfor %}
