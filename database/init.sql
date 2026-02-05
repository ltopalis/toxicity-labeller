CREATE DATABASE evaluation_db
WITH ENCODING='UTF8'
CONNECTION LIMIT=30;

\c evaluation_db;

CREATE TABLE evaluation (
    text_id VARCHAR(40) PRIMARY KEY,
    text TEXT NOT NULL,
    times_evaluated INTEGER NOT NULL DEFAULT 0,
    lang VARCHAR(5) NOT NULL,
    toxicity JSON NOT NULL DEFAULT '{"Implicit": 0 , "Explicit": 0, "Neutral": 0}'::json,
    bias_type JSON NOT NULL DEFAULT '{"Appearance / Physical Bias": 0 , "Cognitive / Intelligence bias": 0, "Gender / Identity bias": 0, "Institutional / Media Bias": 0, "Migration /  Ethnic Bias": 0, "None": 0, "Political / Ideological Bias": 0, "Religious Bias": 0, "Socioeconomic / Educational Bias": 0}'::json,
    target_type JSON NOT NULL DEFAULT '{"Group": 0, "None": 0, "Individual": 0, "Other": 0}'::json
);

CREATE OR REPLACE FUNCTION update_evaluation_from_json(incoming_data JSONB)
RETURNS TEXT AS $$
DECLARE
    target_id VARCHAR;
    sel_toxicity TEXT;
    sel_bias TEXT;
    sel_target TEXT;
BEGIN
    target_id := incoming_data->>'text_id';
    sel_toxicity := incoming_data->>'toxicity';
    sel_bias := incoming_data->>'bias_type';
    sel_target := incoming_data->>'target_type';

    IF NOT EXISTS (SELECT 1 FROM evaluation WHERE text_id = target_id) THEN
        RETURN 'Error: ID not found';
    END IF;

    UPDATE evaluation
    SET 
        times_evaluated = times_evaluated + 1,
        
        toxicity = jsonb_set(
            toxicity::jsonb, 
            array[sel_toxicity], 
            (coalesce((toxicity->>sel_toxicity)::int, 0) + 1)::text::jsonb
        ),
        
        bias_type = jsonb_set(
            bias_type::jsonb, 
            array[sel_bias], 
            (coalesce((bias_type->>sel_bias)::int, 0) + 1)::text::jsonb
        ),
        
        target_type = jsonb_set(
            target_type::jsonb, 
            array[sel_target], 
            (coalesce((target_type->>sel_target)::int, 0) + 1)::text::jsonb
        )
    WHERE text_id = target_id;

    RETURN 'Success: Evaluation updated';
END;
$$ LANGUAGE plpgsql;