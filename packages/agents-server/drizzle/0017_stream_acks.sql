CREATE TABLE IF NOT EXISTS "stream_acks" (
	"tenant_id" text DEFAULT 'default' NOT NULL,
	"stream" text NOT NULL,
	"acked_offset" text NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "stream_acks_tenant_id_stream_pk" PRIMARY KEY("tenant_id","stream")
);
