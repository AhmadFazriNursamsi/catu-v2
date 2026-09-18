CREATE TABLE IF NOT EXISTS "apks" (
	"id" serial PRIMARY KEY NOT NULL,
	"version_name" varchar(50) NOT NULL,
	"version_code" integer NOT NULL,
	"download_url" text NOT NULL,
	"file_size_bytes" integer,
	"is_active" boolean DEFAULT true,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "auth_users" (
	"id" serial PRIMARY KEY NOT NULL,
	"username" varchar(100),
	"password_hash" varchar(255),
	"phone_number" varchar(50) NOT NULL,
	"email" varchar(100),
	"role_id" integer,
	"account_status" varchar(50) DEFAULT 'APPROVED',
	"fcm_token" text,
	"last_login" timestamp,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now(),
	CONSTRAINT "auth_users_phone_number_unique" UNIQUE("phone_number")
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "chat_group_members" (
	"id" serial PRIMARY KEY NOT NULL,
	"chat_group_id" integer NOT NULL,
	"user_id" integer NOT NULL,
	"role_in_group" varchar(50) DEFAULT 'MEMBER',
	"last_read_message_id" integer,
	"joined_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "chat_groups" (
	"id" serial PRIMARY KEY NOT NULL,
	"order_id" integer,
	"name" varchar(255),
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "chat_messages" (
	"id" serial PRIMARY KEY NOT NULL,
	"chat_group_id" integer NOT NULL,
	"sender_id" integer,
	"message_type" varchar(50) DEFAULT 'TEXT',
	"message" text NOT NULL,
	"attachment_url" text,
	"reply_to_message_id" integer,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "keuskupan" (
	"id" integer PRIMARY KEY NOT NULL,
	"name" varchar(255) NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "lingkungan" (
	"id" integer PRIMARY KEY NOT NULL,
	"wilayah_id" integer,
	"name" varchar(255) NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "master_positions" (
	"id" serial PRIMARY KEY NOT NULL,
	"category" varchar(50) NOT NULL,
	"code" varchar(50) NOT NULL,
	"name" varchar(100) NOT NULL,
	"is_lead" boolean DEFAULT false,
	"created_at" timestamp DEFAULT now(),
	CONSTRAINT "master_positions_code_unique" UNIQUE("code")
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "news" (
	"id" serial PRIMARY KEY NOT NULL,
	"title" varchar(255) NOT NULL,
	"content" text,
	"image_url" text,
	"source_url" text,
	"published_at" timestamp,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "notifications" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" integer NOT NULL,
	"title" varchar(255) NOT NULL,
	"body" text NOT NULL,
	"data" text,
	"is_read" boolean DEFAULT false,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "order_items" (
	"id" serial PRIMARY KEY NOT NULL,
	"order_id" integer NOT NULL,
	"scheduled_date" varchar(50),
	"scheduled_time" varchar(50),
	"notes" text,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "order_reschedules" (
	"id" serial PRIMARY KEY NOT NULL,
	"order_id" integer NOT NULL,
	"item_id" integer,
	"proposed_by" integer NOT NULL,
	"previous_date" varchar(50),
	"previous_time_start" varchar(50),
	"previous_time_end" varchar(50),
	"proposed_date" varchar(50) NOT NULL,
	"proposed_time_start" varchar(50) NOT NULL,
	"proposed_time_end" varchar(50),
	"reason" text NOT NULL,
	"status" varchar(50) DEFAULT 'PENDING_UMAT',
	"responded_by" integer,
	"responded_at" timestamp,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "order_romo_handovers" (
	"id" serial PRIMARY KEY NOT NULL,
	"order_id" integer NOT NULL,
	"item_id" integer,
	"previous_romo_id" integer NOT NULL,
	"new_romo_id" integer,
	"handover_type" varchar(50) NOT NULL,
	"reason" text NOT NULL,
	"status" varchar(50) DEFAULT 'COMPLETED',
	"created_at" timestamp DEFAULT now(),
	"responded_at" timestamp
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "orders" (
	"id" serial PRIMARY KEY NOT NULL,
	"order_number" varchar(50) NOT NULL,
	"user_id" integer NOT NULL,
	"category_id" integer NOT NULL,
	"status" varchar(50) DEFAULT 'PENDING',
	"location_name" text,
	"location_address" text,
	"location_latitude" varchar(50),
	"location_longitude" varchar(50),
	"scheduled_date" varchar(50),
	"scheduled_time" varchar(50),
	"notes" text,
	"attachment_url" text,
	"accepted_romo_id" integer,
	"paroki_id" integer,
	"lingkungan_id" integer,
	"keuskupan_id" integer,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now(),
	CONSTRAINT "orders_order_number_unique" UNIQUE("order_number")
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "ordo" (
	"id" integer PRIMARY KEY NOT NULL,
	"code" varchar(50) NOT NULL,
	"name" varchar(255) NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "paroki" (
	"id" integer PRIMARY KEY NOT NULL,
	"name" varchar(255) NOT NULL,
	"keuskupan_id" integer
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "roles" (
	"id" serial PRIMARY KEY NOT NULL,
	"code" varchar(50) NOT NULL,
	"name" varchar(100) NOT NULL,
	"description" text,
	"created_at" timestamp DEFAULT now(),
	CONSTRAINT "roles_code_unique" UNIQUE("code")
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "service_categories" (
	"id" serial PRIMARY KEY NOT NULL,
	"name" varchar(100) NOT NULL,
	"description" text,
	"is_urgent_default" boolean DEFAULT false,
	"is_active" boolean DEFAULT true,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "urgency_levels" (
	"id" serial PRIMARY KEY NOT NULL,
	"code" varchar(50) NOT NULL,
	"name" varchar(100) NOT NULL,
	"hours_threshold" integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "user_profiles" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" integer NOT NULL,
	"full_name" varchar(255) NOT NULL,
	"phone_number" varchar(50),
	"email" varchar(100),
	"keuskupan_id" integer,
	"paroki_id" integer,
	"wilayah_id" integer,
	"lingkungan_id" integer,
	"ordo_id" integer,
	"pengurus_position" varchar(100),
	"romo_position" varchar(100),
	"jabatan_start_year" integer,
	"jabatan_end_year" integer,
	"jabatan_start_date" varchar(20),
	"jabatan_end_date" varchar(20),
	"is_jabatan_active" boolean DEFAULT false,
	"birth_date" varchar(20),
	"address" text,
	"avatar_url" text,
	"created_at" timestamp DEFAULT now(),
	"updated_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "wilayah" (
	"id" integer PRIMARY KEY NOT NULL,
	"paroki_id" integer,
	"name" varchar(255) NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "auth_users" ADD CONSTRAINT "auth_users_role_id_roles_id_fk" FOREIGN KEY ("role_id") REFERENCES "public"."roles"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "chat_group_members" ADD CONSTRAINT "chat_group_members_chat_group_id_chat_groups_id_fk" FOREIGN KEY ("chat_group_id") REFERENCES "public"."chat_groups"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "chat_group_members" ADD CONSTRAINT "chat_group_members_user_id_auth_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."auth_users"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "chat_groups" ADD CONSTRAINT "chat_groups_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_chat_group_id_chat_groups_id_fk" FOREIGN KEY ("chat_group_id") REFERENCES "public"."chat_groups"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_sender_id_auth_users_id_fk" FOREIGN KEY ("sender_id") REFERENCES "public"."auth_users"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "lingkungan" ADD CONSTRAINT "lingkungan_wilayah_id_wilayah_id_fk" FOREIGN KEY ("wilayah_id") REFERENCES "public"."wilayah"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_auth_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."auth_users"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "order_items" ADD CONSTRAINT "order_items_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "order_reschedules" ADD CONSTRAINT "order_reschedules_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "order_reschedules" ADD CONSTRAINT "order_reschedules_proposed_by_auth_users_id_fk" FOREIGN KEY ("proposed_by") REFERENCES "public"."auth_users"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "order_reschedules" ADD CONSTRAINT "order_reschedules_responded_by_auth_users_id_fk" FOREIGN KEY ("responded_by") REFERENCES "public"."auth_users"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "order_romo_handovers" ADD CONSTRAINT "order_romo_handovers_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "order_romo_handovers" ADD CONSTRAINT "order_romo_handovers_previous_romo_id_auth_users_id_fk" FOREIGN KEY ("previous_romo_id") REFERENCES "public"."auth_users"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "order_romo_handovers" ADD CONSTRAINT "order_romo_handovers_new_romo_id_auth_users_id_fk" FOREIGN KEY ("new_romo_id") REFERENCES "public"."auth_users"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "orders" ADD CONSTRAINT "orders_user_id_auth_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."auth_users"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "orders" ADD CONSTRAINT "orders_category_id_service_categories_id_fk" FOREIGN KEY ("category_id") REFERENCES "public"."service_categories"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "paroki" ADD CONSTRAINT "paroki_keuskupan_id_keuskupan_id_fk" FOREIGN KEY ("keuskupan_id") REFERENCES "public"."keuskupan"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_user_id_auth_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."auth_users"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "wilayah" ADD CONSTRAINT "wilayah_paroki_id_paroki_id_fk" FOREIGN KEY ("paroki_id") REFERENCES "public"."paroki"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN OTHERS THEN null;
END $$;