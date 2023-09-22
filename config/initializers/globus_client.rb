# frozen_string_literal: true

GlobusClient.configure(
  client_id: Settings.globus.client_id,
  client_secret: Settings.globus.client_secret,
  uploads_directory: '', # no top-level directory used in preassembly globus endpoint
  transfer_endpoint_id: Settings.globus.endpoint_id
)
