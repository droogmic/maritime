{% if pillar['user'] %}
syncthing:
  pkg:
    - installed
  service.running:
    - name: syncthing@{{ pillar['user'] }}
    - enable: true
    - require:
        - pkg: syncthing
{% else %}
{{ raise('missing user ' + pillar['user']) }}
{% endif %}

keepassxc:
  pkg:
    - installed

# Custom Afval Kalendar
{% if pillar['user'] %}
{% set uid = salt['user.info'](pillar['user']).uid %}
afvalkalendar:
  file.managed:
    - user: {{ pillar['user'] }}
    - group: {{ pillar['user'] }}
    - makedirs: true
    - template: jinja
    - names:
      - /home/{{ pillar['user'] }}/.config/systemd/user/afval.service:
        - source: salt://afval/systemd.service
      - /home/{{ pillar['user'] }}/.config/systemd/user/afval.timer:
        - source: salt://afval/systemd.timer
      - /home/{{ pillar['user'] }}/.cache/afval/notification.py:
        - source: salt://afval/notification.py
      - /home/{{ pillar['user'] }}/.cache/afval/tempvenv:
        - source: salt://afval/tempvenv
        - mode: '0755'
  virtualenv.managed:
    - name: /home/{{ pillar['user'] }}/.cache/afval/venv
    - venv_bin: /home/{{ pillar['user'] }}/.cache/afval/tempvenv
    - pip_upgrade: true
    - pip_pkgs: ['beautifulsoup4', 'requests']
  cmd.run:
    - names:
      - 'systemctl --user daemon-reload'
      - 'systemctl --user enable afval.timer'
      - 'systemctl --user start afval.service'
    - env:
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/{{ uid }}/bus
    - onchanges:
      - file: afvalkalendar
{% else %}
{{ raise('missing user ' + pillar['user']) }}
{% endif %}
