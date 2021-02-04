============================================
Lightweight Directory Access Protocol (LDAP)
============================================

Currently in the Zuul Jarvis job, a sample `OpenLDAP`_ server is deployed via
Helm. A sample user of ``jarvis`` (with ``dn: uid=jarvis,ou=Users,dc=jarvis,dc=local``)
and password ``password`` is created by default to demonstrate successful
LDAP user authentication for the Harbor and Grafana dashboards.

To customize Grafana dashboard, update the following settings in
``./charts/loki/values_overrides/default.yaml``.


.. code:: yaml

  loki-stack:
    grafana:
        auth.ldap:
          enabled: true
      ldap:
        enabled: true
        config: |-
          [[servers]]
          host = "ldap-openldap.ldap.svc.cluster.local"
          port = 389
          use_ssl = false
          start_tls = false
          ssl_skip_verify = false
          bind_dn = "cn=readonly,dc=jarvis,dc=local"
          bind_password = "readonly"
          search_base_dns = ["dc=jarvis,dc=local"]
          search_filter = "(uid=%s)"
          [[servers.group_mappings]]
          group_dn = "cn=jarvis-admins,ou=Groups,dc=jarvis,dc=local"
          org_role = "Admin"
          grafana_admin = true
          [[servers.group_mappings]]
          group_dn = "*"
          org_role = "Viewer"
          [servers.attributes]
          email = "mail"


.. note:: Please consult Grafana's `documentation`_ on LDAP for further details.

To customize the Harbor dashboard, update the following settings in
``./charts/harbor/values.yaml``.


.. code:: yaml

  config:
    test:
      ldap_username: jarvis
      ldap_password: password
    harbor:
      # NOTE(lamt): this url should include the scheme (http or https) and should
      # exclude trailing "/"
      api_url: https://harbor-harbor-core.harbor.svc.cluster.local
      admin_password: Harbor12345
    ldap:
      enabled: true
      data:
        auth_mode: ldap_auth
        ldap_base_dn: 'dc=jarvis,dc=local'
        ldap_search_dn: 'cn=readonly,dc=jarvis,dc=local'
        ldap_search_password: readonly
        ldap_uid: uid
        ldap_url: 'ldap://ldap-openldap.ldap.svc.cluster.local'
        ldap_group_membership_attribute: memberof
        ldap_group_attribute_name: cn
        ldap_group_admin_dn: 'cn=jarvis-admins,ou=Groups,dc=jarvis,dc=local'
        ldap_group_base_dn: 'ou=Groups,dc=jarvis,dc=local'
        # Scope values: 0=Base, 1=OneLevel, 2=Subtree
        ldap_scope: 2
        ldap_group_search_scope: 2
        ldap_verify_cert: false
        ldap_group_search_filter: "objectClass=groupOfUniqueNames"


.. _OpenLDAP: https://www.openldap.org/
.. _documentation: https://grafana.com/docs/grafana/latest/auth/ldap/
