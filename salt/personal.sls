{% if pillar['user'] %}
syncthing:
  file.managed:
    - user: {{ pillar['user'] }}
    - group: {{ pillar['user'] }}
    - template: jinja
    - names:
      - /home/{{ pillar['user'] }}/.bashrc
        - source: salt://personal/.basrhc
{% endif %}

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
      # for normal salt
      #- /home/{{ pillar['user'] }}/.cache/afval/tempvenv:
      #  - source: salt://afval/tempvenv
      #  - mode: '0755'
  virtualenv.managed:
    - name: /home/{{ pillar['user'] }}/.cache/afval/venv
    # for normal salt
    #- venv_bin: /home/{{ pillar['user'] }}/.cache/afval/tempvenv
    - provider: venv
    - pip_upgrade: true
    - pip_pkgs: ['beautifulsoup4', 'requests']
    - user: {{ pillar['user'] }}
  cmd.run:
    - names:
      - 'systemctl --user daemon-reload'
      - 'systemctl --user enable afval.timer'
      - 'systemctl --user start afval.service'
    - runas: {{ pillar['user'] }}
    - env:
      - DBUS_SESSION_BUS_ADDRESS: unix:path=/run/user/{{ uid }}/bus
    - onchanges:
      - file: afvalkalendar
{% else %}
{{ raise('missing user ' + pillar['user']) }}
{% endif %}
