-- PMT contributing attributes for Farmer Registry Household register.
-- Formula: pmt_formula_farmer_registry.html (0–100 scale; lower = more vulnerable).
-- Intercept (50.00) is applied in G2PScoreComputeServicePmt.

INSERT INTO "public"."g2p_register_score_contributing_attributes" ("contributing_attribute_id","register_mnemonic","score_type","attribute_name","attribute_computation_required","attribute_computation_value","attribute_weightage") VALUES
('f2000000-0000-4000-8000-000000000001','Household','PMT','disability_severity','TRUE','{"CANNOT_DO_AT_ALL":1,"A_LOT_OF_DIFFICULTY":2,"SOME_DIFFICULTY":3,"NO_DIFFICULTY":4}','6.36'),
('f2000000-0000-4000-8000-000000000002','Household','PMT','education_level','TRUE','{"ILLITERATE":1,"CAN_READ_AND_WRITE":2,"BASIC":3,"INTERMEDIARY":4,"HIGHER_EDUCATION":5}','5.45'),
('f2000000-0000-4000-8000-000000000003','Household','PMT','size_of_group','FALSE',NULL,'-2.73'),
('f2000000-0000-4000-8000-000000000004','Household','PMT','land_ownership_type','TRUE','{"OWNER":0,"TENANT":-4.55,"CROP_SHARE":-7.27}','1.00');
