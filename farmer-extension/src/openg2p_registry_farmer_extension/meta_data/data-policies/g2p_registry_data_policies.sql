-- Record-level data policies for Farmer Registry demo environments.
-- Policies filter the Farmer register by admin1 geo mnemonic in geo_code_hierarchy_json.
-- Keycloak client roles: DP_<policy_mnemonic> (e.g. DP_region_central) on global.keycloakRealm.
-- Admin API token uses global.keycloakAdminRealm; role CRUD uses global.keycloakRealm.
INSERT INTO "public"."g2p_registry_data_policies" (
    "policy_id",
    "policy_mnemonic",
    "policy_description",
    "register_id",
    "policy_type",
    "policy_filter_expression"
) VALUES
    (
        'f1a10001-0000-4000-8000-000000000001',
        'region_central',
        'Farmers located in the Central admin1 region',
        'a1a4d25a-1cd4-4356-abac-985a0b3c6bcd',
        'ALLOW',
        '{"type":"GROUP","operator":"AND","children":[{"type":"CONDITION","field_id":"geo_code_hierarchy_json","operator":"contains","value":"Central"}]}'::json
    ),
    (
        'f1a10001-0000-4000-8000-000000000002',
        'region_pualula',
        'Farmers located in the Pualula admin1 region',
        'a1a4d25a-1cd4-4356-abac-985a0b3c6bcd',
        'ALLOW',
        '{"type":"GROUP","operator":"AND","children":[{"type":"CONDITION","field_id":"geo_code_hierarchy_json","operator":"contains","value":"Pualula"}]}'::json
    ),
    (
        'f1a10001-0000-4000-8000-000000000003',
        'region_chuminga',
        'Farmers located in the Chuminga admin1 region',
        'a1a4d25a-1cd4-4356-abac-985a0b3c6bcd',
        'ALLOW',
        '{"type":"GROUP","operator":"AND","children":[{"type":"CONDITION","field_id":"geo_code_hierarchy_json","operator":"contains","value":"Chuminga"}]}'::json
    ),
    (
        'f1a10001-0000-4000-8000-000000000004',
        'region_sulaka',
        'Farmers located in the Sulaka admin1 region',
        'a1a4d25a-1cd4-4356-abac-985a0b3c6bcd',
        'ALLOW',
        '{"type":"GROUP","operator":"AND","children":[{"type":"CONDITION","field_id":"geo_code_hierarchy_json","operator":"contains","value":"Sulaka"}]}'::json
    )
ON CONFLICT ("policy_id") DO NOTHING;
