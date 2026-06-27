# Uninstall

Uninstall must remove only REACHABLE-managed marketplace adapter files for the
selected agent.

It must not remove:

- user-authored agent configuration;
- unrelated MCP servers;
- customer source files;
- REACHABLE runtime state unless the user explicitly requests full product
  removal.

After uninstall, `reachable: doctor` should either be unavailable in the agent
or should report that the plugin adapter is not installed.
