-- 0000_baseline: skema lengkap CATU untuk database BARU (dibangkitkan dari skema akhir yang sudah distandarkan).
--
-- Database yang sudah ada (sudah memakai migrasi lama) melewati berkas ini dan hanya menjalankan 0001_standardization.
-- Tidak berisi data. Data referensi diisi oleh 0001_standardization dan data master wilayah oleh aplikasi (master_data_seed.sql).
-- Jangan diedit: perubahan skema berikutnya dibuat sebagai migrasi bernomor baru (lihat backend/drizzle/README.md).

CREATE EXTENSION IF NOT EXISTS pgcrypto;

--
-- PostgreSQL database dump
--

-- Dumped from database version 16.14
-- Dumped by pg_dump version 16.14

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

--
-- Name: account_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.account_status_enum AS ENUM (
    'PENDING_APPROVAL',
    'APPROVED',
    'REJECTED'
);

--
-- Name: assignment_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.assignment_status_enum AS ENUM (
    'WAITING',
    'ACCEPTED',
    'DECLINED'
);

--
-- Name: chat_message_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.chat_message_type_enum AS ENUM (
    'TEXT',
    'IMAGE',
    'DOCUMENT',
    'LOCATION',
    'SYSTEM_EVENT'
);

--
-- Name: device_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.device_type_enum AS ENUM (
    'ANDROID',
    'IOS',
    'WEB'
);

--
-- Name: monitor_role_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.monitor_role_enum AS ENUM (
    'PENGURUS_LINGKUNGAN',
    'KOORDINATOR_KEUSKUPAN'
);

--
-- Name: order_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.order_status_enum AS ENUM (
    'PENDING',
    'ACCEPTED',
    'REJECTED',
    'IN_PROGRESS',
    'COMPLETED',
    'CANCELLED',
    'CONFIRMED',
    'DONE',
    'CLOSE',
    'FAIL'
);

--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at := CURRENT_TIMESTAMP;
  RETURN NEW;
END $$;

--
-- Name: activity_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_logs (
    id integer NOT NULL,
    user_id integer,
    user_name character varying(255),
    user_role character varying(50),
    action character varying(100) NOT NULL,
    target_entity character varying(50),
    target_id character varying(100),
    description text NOT NULL,
    ip_address character varying(50),
    user_agent text,
    metadata text,
    created_at timestamp with time zone DEFAULT now()
);

--
-- Name: activity_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.activity_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: activity_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.activity_logs_id_seq OWNED BY public.activity_logs.id;

--
-- Name: apks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.apks (
    id integer NOT NULL,
    version_name character varying(50) NOT NULL,
    version_code integer NOT NULL,
    download_url text NOT NULL,
    file_size_bytes integer,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);

--
-- Name: apks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.apks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: apks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.apks_id_seq OWNED BY public.apks.id;

--
-- Name: app_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_settings (
    key character varying(100) NOT NULL,
    value text NOT NULL,
    description text,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);

--
-- Name: auth_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_users (
    id bigint NOT NULL,
    uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    role_id integer NOT NULL,
    phone_number character varying(20) NOT NULL,
    password_hash character varying(255) NOT NULL,
    account_status public.account_status_enum DEFAULT 'PENDING_APPROVAL'::public.account_status_enum NOT NULL,
    approval_assigned_to_user_id bigint,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_auth_users_phone_format CHECK (((phone_number)::text ~ '^[0-9]{9,16}$'::text))
);

--
-- Name: auth_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.auth_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: auth_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.auth_users_id_seq OWNED BY public.auth_users.id;

--
-- Name: chat_group_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_group_members (
    id bigint NOT NULL,
    chat_group_id bigint NOT NULL,
    user_id bigint NOT NULL,
    role_in_group character varying(50) NOT NULL,
    last_read_message_id bigint,
    joined_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);

--
-- Name: chat_group_members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_group_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: chat_group_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_group_members_id_seq OWNED BY public.chat_group_members.id;

--
-- Name: chat_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_groups (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    title character varying(150) NOT NULL,
    last_message_text text,
    last_message_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    order_item_id bigint,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);

--
-- Name: chat_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: chat_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_groups_id_seq OWNED BY public.chat_groups.id;

--
-- Name: chat_message_reads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_message_reads (
    id bigint NOT NULL,
    message_id bigint NOT NULL,
    user_id bigint NOT NULL,
    read_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);

--
-- Name: chat_message_reads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_message_reads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: chat_message_reads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_message_reads_id_seq OWNED BY public.chat_message_reads.id;

--
-- Name: chat_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_messages (
    id bigint NOT NULL,
    chat_group_id bigint NOT NULL,
    sender_id bigint,
    message_type public.chat_message_type_enum DEFAULT 'TEXT'::public.chat_message_type_enum NOT NULL,
    message text NOT NULL,
    attachment_url text,
    reply_to_message_id bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);

--
-- Name: chat_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: chat_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_messages_id_seq OWNED BY public.chat_messages.id;

--
-- Name: kabupaten_kota; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kabupaten_kota (
    id bigint NOT NULL,
    provinsi_id bigint NOT NULL,
    name character varying(100) NOT NULL,
    type character varying(20) DEFAULT 'KOTA'::character varying
);

--
-- Name: kabupaten_kota_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.kabupaten_kota_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: kabupaten_kota_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.kabupaten_kota_id_seq OWNED BY public.kabupaten_kota.id;

--
-- Name: keuskupan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.keuskupan (
    id bigint NOT NULL,
    name character varying(150) NOT NULL,
    code character varying(50),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

--
-- Name: keuskupan_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.keuskupan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: keuskupan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.keuskupan_id_seq OWNED BY public.keuskupan.id;

--
-- Name: lingkungan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lingkungan (
    id bigint NOT NULL,
    wilayah_id bigint NOT NULL,
    name character varying(150) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

--
-- Name: lingkungan_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.lingkungan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: lingkungan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.lingkungan_id_seq OWNED BY public.lingkungan.id;

--
-- Name: master_positions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.master_positions (
    id integer NOT NULL,
    category character varying(50) NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    is_lead boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

--
-- Name: master_positions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.master_positions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: master_positions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.master_positions_id_seq OWNED BY public.master_positions.id;

--
-- Name: news; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    content text,
    image_url text,
    source_url text,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);

--
-- Name: news_article_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news_article_tags (
    article_id bigint NOT NULL,
    tag_id bigint NOT NULL
);

--
-- Name: news_articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news_articles (
    id bigint NOT NULL,
    source_id bigint,
    category_id bigint,
    guid character varying(255) NOT NULL,
    title character varying(255) NOT NULL,
    slug character varying(300) NOT NULL,
    summary text,
    content_html text,
    content_text text,
    author character varying(100),
    original_url text NOT NULL,
    image_url text,
    published_at timestamp with time zone NOT NULL,
    scraped_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    status character varying(20) DEFAULT 'PUBLISHED'::character varying,
    view_count integer DEFAULT 0,
    share_count integer DEFAULT 0,
    is_featured boolean DEFAULT false,
    is_editors_choice boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

--
-- Name: news_articles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_articles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: news_articles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_articles_id_seq OWNED BY public.news_articles.id;

--
-- Name: news_bookmarks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news_bookmarks (
    id bigint NOT NULL,
    user_id bigint,
    article_id bigint,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

--
-- Name: news_bookmarks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_bookmarks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: news_bookmarks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_bookmarks_id_seq OWNED BY public.news_bookmarks.id;

--
-- Name: news_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news_categories (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    slug character varying(100) NOT NULL,
    description text,
    icon_name character varying(50),
    display_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

--
-- Name: news_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: news_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_categories_id_seq OWNED BY public.news_categories.id;

--
-- Name: news_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: news_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_id_seq OWNED BY public.news.id;

--
-- Name: news_scrape_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news_scrape_logs (
    id bigint NOT NULL,
    source_id bigint,
    started_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    finished_at timestamp with time zone,
    status character varying(20) NOT NULL,
    items_found integer DEFAULT 0,
    items_inserted integer DEFAULT 0,
    items_skipped integer DEFAULT 0,
    error_log text
);

--
-- Name: news_scrape_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_scrape_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: news_scrape_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_scrape_logs_id_seq OWNED BY public.news_scrape_logs.id;

--
-- Name: news_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news_sources (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    code character varying(50) NOT NULL,
    base_url character varying(255) NOT NULL,
    feed_url character varying(255),
    scraper_type character varying(30) DEFAULT 'RSS'::character varying,
    scraper_selectors jsonb,
    crawl_interval_minutes integer DEFAULT 60,
    is_active boolean DEFAULT true,
    logo_url text,
    last_scraped_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

--
-- Name: news_sources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: news_sources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_sources_id_seq OWNED BY public.news_sources.id;

--
-- Name: news_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news_tags (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    slug character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

--
-- Name: news_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: news_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_tags_id_seq OWNED BY public.news_tags.id;

--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    order_id bigint,
    title character varying(150) NOT NULL,
    body text NOT NULL,
    type character varying(50) NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    chat_group_id bigint,
    CONSTRAINT chk_notifications_type_format CHECK (((type)::text ~ '^[A-Z][A-Z0-9_]*$'::text))
);

--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;

--
-- Name: order_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_assignments (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    romo_id bigint NOT NULL,
    status public.assignment_status_enum DEFAULT 'WAITING'::public.assignment_status_enum NOT NULL,
    decline_reason text,
    assigned_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    responded_at timestamp with time zone
);

--
-- Name: order_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: order_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_assignments_id_seq OWNED BY public.order_assignments.id;

--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    item_name character varying(150) NOT NULL,
    scheduled_date date NOT NULL,
    scheduled_time_start time without time zone NOT NULL,
    scheduled_time_end time without time zone NOT NULL,
    location_name character varying(200) NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    accepted_romo_id integer,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    reschedule_status character varying(30) DEFAULT 'NONE'::character varying,
    reschedule_proposed_by integer,
    reschedule_new_date date,
    reschedule_new_time_start time without time zone,
    reschedule_new_time_end time without time zone,
    reschedule_reason text,
    handover_status character varying(30) DEFAULT 'NONE'::character varying,
    handover_proposed_by bigint,
    handover_target_romo_id bigint,
    handover_reason text,
    external_romo_name character varying(255),
    rating integer,
    review_notes text,
    reviewed_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_order_items_handover_status CHECK (((handover_status)::text = ANY (ARRAY['NONE'::text, 'PENDING'::text, 'ACCEPTED'::text, 'REJECTED'::text]))),
    CONSTRAINT chk_order_items_rating CHECK (((rating IS NULL) OR ((rating >= 1) AND (rating <= 5)))),
    CONSTRAINT chk_order_items_reschedule_status CHECK (((reschedule_status)::text = ANY (ARRAY['NONE'::text, 'PENDING_UMAT'::text, 'ACCEPTED'::text, 'REJECTED'::text]))),
    CONSTRAINT chk_order_items_status CHECK (((status)::text = ANY (ARRAY['PENDING'::text, 'CONFIRMED'::text, 'IN_PROGRESS'::text, 'DONE'::text, 'CLOSE'::text, 'FAIL'::text]))),
    CONSTRAINT chk_order_items_time_range CHECK ((scheduled_time_end > scheduled_time_start))
);

--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_items_id_seq OWNED BY public.order_items.id;

--
-- Name: order_monitors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_monitors (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    user_id bigint NOT NULL,
    monitor_role public.monitor_role_enum NOT NULL,
    notified_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);

--
-- Name: order_monitors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_monitors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: order_monitors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_monitors_id_seq OWNED BY public.order_monitors.id;

--
-- Name: order_number_counters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_number_counters (
    key character varying(40) NOT NULL,
    last_value integer DEFAULT 0 NOT NULL
);

--
-- Name: order_reschedules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_reschedules (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    item_id bigint,
    proposed_by integer NOT NULL,
    previous_date date,
    previous_time_start time without time zone,
    previous_time_end time without time zone,
    proposed_date date NOT NULL,
    proposed_time_start time without time zone NOT NULL,
    proposed_time_end time without time zone,
    reason text NOT NULL,
    status character varying(30) DEFAULT 'PENDING_UMAT'::character varying,
    responded_by integer,
    responded_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_order_reschedules_status CHECK (((status)::text = ANY (ARRAY['PENDING_UMAT'::text, 'ACCEPTED'::text, 'REJECTED'::text])))
);

--
-- Name: order_reschedules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_reschedules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: order_reschedules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_reschedules_id_seq OWNED BY public.order_reschedules.id;

--
-- Name: order_romo_handovers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_romo_handovers (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    item_id bigint,
    previous_romo_id integer NOT NULL,
    new_romo_id integer,
    handover_type character varying(30) NOT NULL,
    reason text NOT NULL,
    status character varying(30) DEFAULT 'COMPLETED'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    responded_at timestamp with time zone,
    external_romo_name character varying(255),
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_order_romo_handovers_status CHECK (((status)::text = ANY (ARRAY['PENDING'::text, 'ACCEPTED'::text, 'REJECTED'::text])))
);

--
-- Name: order_romo_handovers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_romo_handovers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: order_romo_handovers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_romo_handovers_id_seq OWNED BY public.order_romo_handovers.id;

--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id bigint NOT NULL,
    order_number character varying(30) NOT NULL,
    user_id bigint NOT NULL,
    service_category_id integer NOT NULL,
    urgency_level_id integer NOT NULL,
    keuskupan_id bigint,
    paroki_id bigint,
    wilayah_id bigint,
    lingkungan_id bigint,
    kabupaten_kota_id bigint,
    status public.order_status_enum DEFAULT 'PENDING'::public.order_status_enum NOT NULL,
    scheduled_date date NOT NULL,
    scheduled_time time without time zone NOT NULL,
    location_name character varying(200) NOT NULL,
    address_detail text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    attachment_url text,
    accepted_romo_id integer,
    reschedule_status character varying(30) DEFAULT 'NONE'::character varying,
    reschedule_proposed_by integer,
    reschedule_new_date date,
    reschedule_new_time time without time zone,
    reschedule_new_time_end time without time zone,
    reschedule_reason text,
    handover_status character varying(30) DEFAULT 'NONE'::character varying,
    handover_proposed_by bigint,
    handover_target_romo_id bigint,
    handover_reason text,
    external_romo_name character varying(255),
    rating integer,
    review_notes text,
    reviewed_at timestamp with time zone,
    ordo_notified_at timestamp with time zone,
    koordinator_notified_at timestamp with time zone,
    lintas_paroki boolean DEFAULT false NOT NULL,
    CONSTRAINT chk_orders_handover_status CHECK (((handover_status)::text = ANY (ARRAY['NONE'::text, 'PENDING'::text, 'ACCEPTED'::text, 'REJECTED'::text]))),
    CONSTRAINT chk_orders_rating CHECK (((rating IS NULL) OR ((rating >= 1) AND (rating <= 5)))),
    CONSTRAINT chk_orders_reschedule_status CHECK (((reschedule_status)::text = ANY (ARRAY['NONE'::text, 'PENDING_UMAT'::text, 'ACCEPTED'::text, 'REJECTED'::text]))),
    CONSTRAINT chk_orders_status CHECK (((status)::text = ANY (ARRAY['PENDING'::text, 'CONFIRMED'::text, 'IN_PROGRESS'::text, 'DONE'::text, 'CLOSE'::text, 'FAIL'::text])))
);

--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;

--
-- Name: ordo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ordo (
    id integer NOT NULL,
    name character varying(150) NOT NULL,
    code character varying(20),
    address text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

--
-- Name: ordo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ordo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: ordo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ordo_id_seq OWNED BY public.ordo.id;

--
-- Name: paroki; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paroki (
    id bigint NOT NULL,
    keuskupan_id bigint NOT NULL,
    name character varying(150) NOT NULL,
    address text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

--
-- Name: paroki_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.paroki_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: paroki_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.paroki_id_seq OWNED BY public.paroki.id;

--
-- Name: provinsi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.provinsi (
    id bigint NOT NULL,
    name character varying(100) NOT NULL
);

--
-- Name: provinsi_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.provinsi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: provinsi_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.provinsi_id_seq OWNED BY public.provinsi.id;

--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(100) NOT NULL
);

--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;

--
-- Name: romo_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.romo_profiles (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ordo_id integer,
    is_external boolean DEFAULT false NOT NULL,
    max_service_duration_minutes integer DEFAULT 60 NOT NULL,
    status_tugas character varying(50) DEFAULT 'AKTIF'::character varying NOT NULL
);

--
-- Name: romo_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.romo_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: romo_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.romo_profiles_id_seq OWNED BY public.romo_profiles.id;

--
-- Name: service_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.service_categories (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    is_urgent_by_default boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);

--
-- Name: service_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.service_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: service_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.service_categories_id_seq OWNED BY public.service_categories.id;

--
-- Name: urgency_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.urgency_levels (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    level integer NOT NULL
);

--
-- Name: urgency_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.urgency_levels_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: urgency_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.urgency_levels_id_seq OWNED BY public.urgency_levels.id;

--
-- Name: user_approvals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_approvals (
    id bigint NOT NULL,
    target_user_id bigint NOT NULL,
    approver_user_id bigint NOT NULL,
    action character varying(20) NOT NULL,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);

--
-- Name: user_approvals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_approvals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: user_approvals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_approvals_id_seq OWNED BY public.user_approvals.id;

--
-- Name: user_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_devices (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    fcm_token text NOT NULL,
    device_type public.device_type_enum DEFAULT 'ANDROID'::public.device_type_enum NOT NULL,
    device_model character varying(100),
    last_active_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);

--
-- Name: user_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_devices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: user_devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_devices_id_seq OWNED BY public.user_devices.id;

--
-- Name: user_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_profiles (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    full_name character varying(150) NOT NULL,
    email character varying(100),
    keuskupan_id bigint,
    paroki_id bigint,
    wilayah_id bigint,
    lingkungan_id bigint,
    kabupaten_kota_id bigint,
    pengurus_position character varying(100),
    romo_position character varying(100) DEFAULT 'ROMO_BIASA'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    jabatan_start_year integer,
    jabatan_end_year integer,
    jabatan_start_date character varying(20),
    jabatan_end_date character varying(20),
    is_jabatan_active boolean DEFAULT false,
    birth_date character varying(20),
    address text,
    avatar_url text,
    ordo_id integer,
    gender character varying(1),
    CONSTRAINT chk_user_profiles_gender CHECK (((gender)::text = ANY (ARRAY['L'::text, 'P'::text])))
);

--
-- Name: user_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: user_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_profiles_id_seq OWNED BY public.user_profiles.id;

--
-- Name: wilayah; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wilayah (
    id bigint NOT NULL,
    paroki_id bigint NOT NULL,
    name character varying(150) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);

--
-- Name: wilayah_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.wilayah_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: wilayah_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.wilayah_id_seq OWNED BY public.wilayah.id;

--
-- Name: activity_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_logs ALTER COLUMN id SET DEFAULT nextval('public.activity_logs_id_seq'::regclass);

--
-- Name: apks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apks ALTER COLUMN id SET DEFAULT nextval('public.apks_id_seq'::regclass);

--
-- Name: auth_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_users ALTER COLUMN id SET DEFAULT nextval('public.auth_users_id_seq'::regclass);

--
-- Name: chat_group_members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_group_members ALTER COLUMN id SET DEFAULT nextval('public.chat_group_members_id_seq'::regclass);

--
-- Name: chat_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_groups ALTER COLUMN id SET DEFAULT nextval('public.chat_groups_id_seq'::regclass);

--
-- Name: chat_message_reads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_reads ALTER COLUMN id SET DEFAULT nextval('public.chat_message_reads_id_seq'::regclass);

--
-- Name: chat_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages ALTER COLUMN id SET DEFAULT nextval('public.chat_messages_id_seq'::regclass);

--
-- Name: kabupaten_kota id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kabupaten_kota ALTER COLUMN id SET DEFAULT nextval('public.kabupaten_kota_id_seq'::regclass);

--
-- Name: keuskupan id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.keuskupan ALTER COLUMN id SET DEFAULT nextval('public.keuskupan_id_seq'::regclass);

--
-- Name: lingkungan id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lingkungan ALTER COLUMN id SET DEFAULT nextval('public.lingkungan_id_seq'::regclass);

--
-- Name: master_positions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_positions ALTER COLUMN id SET DEFAULT nextval('public.master_positions_id_seq'::regclass);

--
-- Name: news id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news ALTER COLUMN id SET DEFAULT nextval('public.news_id_seq'::regclass);

--
-- Name: news_articles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_articles ALTER COLUMN id SET DEFAULT nextval('public.news_articles_id_seq'::regclass);

--
-- Name: news_bookmarks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_bookmarks ALTER COLUMN id SET DEFAULT nextval('public.news_bookmarks_id_seq'::regclass);

--
-- Name: news_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_categories ALTER COLUMN id SET DEFAULT nextval('public.news_categories_id_seq'::regclass);

--
-- Name: news_scrape_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_scrape_logs ALTER COLUMN id SET DEFAULT nextval('public.news_scrape_logs_id_seq'::regclass);

--
-- Name: news_sources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_sources ALTER COLUMN id SET DEFAULT nextval('public.news_sources_id_seq'::regclass);

--
-- Name: news_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_tags ALTER COLUMN id SET DEFAULT nextval('public.news_tags_id_seq'::regclass);

--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);

--
-- Name: order_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_assignments ALTER COLUMN id SET DEFAULT nextval('public.order_assignments_id_seq'::regclass);

--
-- Name: order_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items ALTER COLUMN id SET DEFAULT nextval('public.order_items_id_seq'::regclass);

--
-- Name: order_monitors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_monitors ALTER COLUMN id SET DEFAULT nextval('public.order_monitors_id_seq'::regclass);

--
-- Name: order_reschedules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_reschedules ALTER COLUMN id SET DEFAULT nextval('public.order_reschedules_id_seq'::regclass);

--
-- Name: order_romo_handovers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_romo_handovers ALTER COLUMN id SET DEFAULT nextval('public.order_romo_handovers_id_seq'::regclass);

--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);

--
-- Name: ordo id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ordo ALTER COLUMN id SET DEFAULT nextval('public.ordo_id_seq'::regclass);

--
-- Name: paroki id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paroki ALTER COLUMN id SET DEFAULT nextval('public.paroki_id_seq'::regclass);

--
-- Name: provinsi id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.provinsi ALTER COLUMN id SET DEFAULT nextval('public.provinsi_id_seq'::regclass);

--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);

--
-- Name: romo_profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.romo_profiles ALTER COLUMN id SET DEFAULT nextval('public.romo_profiles_id_seq'::regclass);

--
-- Name: service_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_categories ALTER COLUMN id SET DEFAULT nextval('public.service_categories_id_seq'::regclass);

--
-- Name: urgency_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.urgency_levels ALTER COLUMN id SET DEFAULT nextval('public.urgency_levels_id_seq'::regclass);

--
-- Name: user_approvals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_approvals ALTER COLUMN id SET DEFAULT nextval('public.user_approvals_id_seq'::regclass);

--
-- Name: user_devices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_devices ALTER COLUMN id SET DEFAULT nextval('public.user_devices_id_seq'::regclass);

--
-- Name: user_profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles ALTER COLUMN id SET DEFAULT nextval('public.user_profiles_id_seq'::regclass);

--
-- Name: wilayah id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wilayah ALTER COLUMN id SET DEFAULT nextval('public.wilayah_id_seq'::regclass);

--
-- Name: activity_logs activity_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_logs
    ADD CONSTRAINT activity_logs_pkey PRIMARY KEY (id);

--
-- Name: apks apks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apks
    ADD CONSTRAINT apks_pkey PRIMARY KEY (id);

--
-- Name: app_settings app_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_settings
    ADD CONSTRAINT app_settings_pkey PRIMARY KEY (key);

--
-- Name: auth_users auth_users_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_users
    ADD CONSTRAINT auth_users_phone_number_key UNIQUE (phone_number);

--
-- Name: auth_users auth_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_users
    ADD CONSTRAINT auth_users_pkey PRIMARY KEY (id);

--
-- Name: auth_users auth_users_uuid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_users
    ADD CONSTRAINT auth_users_uuid_key UNIQUE (uuid);

--
-- Name: chat_group_members chat_group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_group_members
    ADD CONSTRAINT chat_group_members_pkey PRIMARY KEY (id);

--
-- Name: chat_groups chat_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_groups
    ADD CONSTRAINT chat_groups_pkey PRIMARY KEY (id);

--
-- Name: chat_message_reads chat_message_reads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_reads
    ADD CONSTRAINT chat_message_reads_pkey PRIMARY KEY (id);

--
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);

--
-- Name: kabupaten_kota kabupaten_kota_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kabupaten_kota
    ADD CONSTRAINT kabupaten_kota_pkey PRIMARY KEY (id);

--
-- Name: keuskupan keuskupan_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.keuskupan
    ADD CONSTRAINT keuskupan_code_key UNIQUE (code);

--
-- Name: keuskupan keuskupan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.keuskupan
    ADD CONSTRAINT keuskupan_pkey PRIMARY KEY (id);

--
-- Name: lingkungan lingkungan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lingkungan
    ADD CONSTRAINT lingkungan_pkey PRIMARY KEY (id);

--
-- Name: master_positions master_positions_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_positions
    ADD CONSTRAINT master_positions_code_key UNIQUE (code);

--
-- Name: master_positions master_positions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_positions
    ADD CONSTRAINT master_positions_pkey PRIMARY KEY (id);

--
-- Name: news_article_tags news_article_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_article_tags
    ADD CONSTRAINT news_article_tags_pkey PRIMARY KEY (article_id, tag_id);

--
-- Name: news_articles news_articles_guid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_articles
    ADD CONSTRAINT news_articles_guid_key UNIQUE (guid);

--
-- Name: news_articles news_articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_articles
    ADD CONSTRAINT news_articles_pkey PRIMARY KEY (id);

--
-- Name: news_articles news_articles_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_articles
    ADD CONSTRAINT news_articles_slug_key UNIQUE (slug);

--
-- Name: news_bookmarks news_bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_bookmarks
    ADD CONSTRAINT news_bookmarks_pkey PRIMARY KEY (id);

--
-- Name: news_categories news_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_categories
    ADD CONSTRAINT news_categories_pkey PRIMARY KEY (id);

--
-- Name: news_categories news_categories_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_categories
    ADD CONSTRAINT news_categories_slug_key UNIQUE (slug);

--
-- Name: news news_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news
    ADD CONSTRAINT news_pkey PRIMARY KEY (id);

--
-- Name: news_scrape_logs news_scrape_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_scrape_logs
    ADD CONSTRAINT news_scrape_logs_pkey PRIMARY KEY (id);

--
-- Name: news_sources news_sources_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_sources
    ADD CONSTRAINT news_sources_code_key UNIQUE (code);

--
-- Name: news_sources news_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_sources
    ADD CONSTRAINT news_sources_pkey PRIMARY KEY (id);

--
-- Name: news_tags news_tags_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_tags
    ADD CONSTRAINT news_tags_name_key UNIQUE (name);

--
-- Name: news_tags news_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_tags
    ADD CONSTRAINT news_tags_pkey PRIMARY KEY (id);

--
-- Name: news_tags news_tags_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_tags
    ADD CONSTRAINT news_tags_slug_key UNIQUE (slug);

--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);

--
-- Name: order_assignments order_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_assignments
    ADD CONSTRAINT order_assignments_pkey PRIMARY KEY (id);

--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);

--
-- Name: order_monitors order_monitors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_monitors
    ADD CONSTRAINT order_monitors_pkey PRIMARY KEY (id);

--
-- Name: order_number_counters order_number_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_number_counters
    ADD CONSTRAINT order_number_counters_pkey PRIMARY KEY (key);

--
-- Name: order_reschedules order_reschedules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_reschedules
    ADD CONSTRAINT order_reschedules_pkey PRIMARY KEY (id);

--
-- Name: order_romo_handovers order_romo_handovers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_romo_handovers
    ADD CONSTRAINT order_romo_handovers_pkey PRIMARY KEY (id);

--
-- Name: orders orders_order_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_order_number_key UNIQUE (order_number);

--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);

--
-- Name: ordo ordo_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ordo
    ADD CONSTRAINT ordo_code_key UNIQUE (code);

--
-- Name: ordo ordo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ordo
    ADD CONSTRAINT ordo_pkey PRIMARY KEY (id);

--
-- Name: paroki paroki_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paroki
    ADD CONSTRAINT paroki_pkey PRIMARY KEY (id);

--
-- Name: provinsi provinsi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.provinsi
    ADD CONSTRAINT provinsi_pkey PRIMARY KEY (id);

--
-- Name: roles roles_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_code_key UNIQUE (code);

--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);

--
-- Name: romo_profiles romo_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.romo_profiles
    ADD CONSTRAINT romo_profiles_pkey PRIMARY KEY (id);

--
-- Name: romo_profiles romo_profiles_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.romo_profiles
    ADD CONSTRAINT romo_profiles_user_id_key UNIQUE (user_id);

--
-- Name: service_categories service_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.service_categories
    ADD CONSTRAINT service_categories_pkey PRIMARY KEY (id);

--
-- Name: chat_group_members unique_group_member; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_group_members
    ADD CONSTRAINT unique_group_member UNIQUE (chat_group_id, user_id);

--
-- Name: chat_message_reads unique_message_read; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_reads
    ADD CONSTRAINT unique_message_read UNIQUE (message_id, user_id);

--
-- Name: order_monitors unique_order_monitor; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_monitors
    ADD CONSTRAINT unique_order_monitor UNIQUE (order_id, user_id);

--
-- Name: news_bookmarks unique_user_article_bookmark; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_bookmarks
    ADD CONSTRAINT unique_user_article_bookmark UNIQUE (user_id, article_id);

--
-- Name: user_devices unique_user_fcm; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_devices
    ADD CONSTRAINT unique_user_fcm UNIQUE (user_id, fcm_token);

--
-- Name: urgency_levels urgency_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.urgency_levels
    ADD CONSTRAINT urgency_levels_pkey PRIMARY KEY (id);

--
-- Name: user_approvals user_approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_approvals
    ADD CONSTRAINT user_approvals_pkey PRIMARY KEY (id);

--
-- Name: user_devices user_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_devices
    ADD CONSTRAINT user_devices_pkey PRIMARY KEY (id);

--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (id);

--
-- Name: user_profiles user_profiles_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_user_id_key UNIQUE (user_id);

--
-- Name: wilayah wilayah_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wilayah
    ADD CONSTRAINT wilayah_pkey PRIMARY KEY (id);

--
-- Name: idx_chat_groups_last_msg_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chat_groups_last_msg_at ON public.chat_groups USING btree (last_message_at DESC);

--
-- Name: idx_chat_groups_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chat_groups_order_id ON public.chat_groups USING btree (order_id);

--
-- Name: idx_chat_messages_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chat_messages_group_id ON public.chat_messages USING btree (chat_group_id, id DESC);

--
-- Name: idx_chat_messages_group_sender; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chat_messages_group_sender ON public.chat_messages USING btree (chat_group_id, sender_id);

--
-- Name: idx_news_articles_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_articles_category ON public.news_articles USING btree (category_id);

--
-- Name: idx_news_articles_featured; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_articles_featured ON public.news_articles USING btree (is_featured) WHERE (is_featured = true);

--
-- Name: idx_news_articles_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_articles_published_at ON public.news_articles USING btree (published_at DESC);

--
-- Name: idx_news_articles_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_articles_source ON public.news_articles USING btree (source_id);

--
-- Name: ix_activity_logs_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_activity_logs_created_at ON public.activity_logs USING btree (created_at DESC);

--
-- Name: ix_activity_logs_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_activity_logs_user_id ON public.activity_logs USING btree (user_id);

--
-- Name: ix_auth_users_account_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_auth_users_account_status ON public.auth_users USING btree (account_status);

--
-- Name: ix_auth_users_approval_assigned_to_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_auth_users_approval_assigned_to_user_id ON public.auth_users USING btree (approval_assigned_to_user_id);

--
-- Name: ix_auth_users_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_auth_users_role_id ON public.auth_users USING btree (role_id);

--
-- Name: ix_chat_group_members_last_read_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chat_group_members_last_read_message_id ON public.chat_group_members USING btree (last_read_message_id);

--
-- Name: ix_chat_group_members_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chat_group_members_user_id ON public.chat_group_members USING btree (user_id);

--
-- Name: ix_chat_groups_order_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chat_groups_order_item_id ON public.chat_groups USING btree (order_item_id);

--
-- Name: ix_chat_message_reads_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chat_message_reads_user_id ON public.chat_message_reads USING btree (user_id);

--
-- Name: ix_chat_messages_reply_to_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chat_messages_reply_to_message_id ON public.chat_messages USING btree (reply_to_message_id);

--
-- Name: ix_chat_messages_sender_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chat_messages_sender_id ON public.chat_messages USING btree (sender_id);

--
-- Name: ix_kabupaten_kota_provinsi_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_kabupaten_kota_provinsi_id ON public.kabupaten_kota USING btree (provinsi_id);

--
-- Name: ix_lingkungan_wilayah_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_lingkungan_wilayah_id ON public.lingkungan USING btree (wilayah_id);

--
-- Name: ix_news_article_tags_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_news_article_tags_tag_id ON public.news_article_tags USING btree (tag_id);

--
-- Name: ix_news_bookmarks_article_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_news_bookmarks_article_id ON public.news_bookmarks USING btree (article_id);

--
-- Name: ix_news_scrape_logs_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_news_scrape_logs_source_id ON public.news_scrape_logs USING btree (source_id);

--
-- Name: ix_notifications_chat_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_notifications_chat_group_id ON public.notifications USING btree (chat_group_id);

--
-- Name: ix_notifications_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_notifications_order_id ON public.notifications USING btree (order_id);

--
-- Name: ix_notifications_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_notifications_user_created ON public.notifications USING btree (user_id, created_at DESC);

--
-- Name: ix_notifications_user_unread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_notifications_user_unread ON public.notifications USING btree (user_id) WHERE (NOT is_read);

--
-- Name: ix_order_assignments_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_assignments_order_id ON public.order_assignments USING btree (order_id);

--
-- Name: ix_order_assignments_romo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_assignments_romo_id ON public.order_assignments USING btree (romo_id);

--
-- Name: ix_order_items_accepted_romo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_items_accepted_romo_id ON public.order_items USING btree (accepted_romo_id);

--
-- Name: ix_order_items_handover_proposed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_items_handover_proposed_by ON public.order_items USING btree (handover_proposed_by);

--
-- Name: ix_order_items_handover_target_romo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_items_handover_target_romo_id ON public.order_items USING btree (handover_target_romo_id);

--
-- Name: ix_order_items_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_items_order_id ON public.order_items USING btree (order_id);

--
-- Name: ix_order_items_reschedule_proposed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_items_reschedule_proposed_by ON public.order_items USING btree (reschedule_proposed_by);

--
-- Name: ix_order_items_status_scheduled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_items_status_scheduled ON public.order_items USING btree (status, scheduled_date);

--
-- Name: ix_order_monitors_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_monitors_user_id ON public.order_monitors USING btree (user_id);

--
-- Name: ix_order_reschedules_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_reschedules_item_id ON public.order_reschedules USING btree (item_id);

--
-- Name: ix_order_reschedules_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_reschedules_order_id ON public.order_reschedules USING btree (order_id);

--
-- Name: ix_order_reschedules_proposed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_reschedules_proposed_by ON public.order_reschedules USING btree (proposed_by);

--
-- Name: ix_order_reschedules_responded_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_reschedules_responded_by ON public.order_reschedules USING btree (responded_by);

--
-- Name: ix_order_romo_handovers_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_romo_handovers_item_id ON public.order_romo_handovers USING btree (item_id);

--
-- Name: ix_order_romo_handovers_new_romo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_romo_handovers_new_romo_id ON public.order_romo_handovers USING btree (new_romo_id);

--
-- Name: ix_order_romo_handovers_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_romo_handovers_order_id ON public.order_romo_handovers USING btree (order_id);

--
-- Name: ix_order_romo_handovers_previous_romo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_order_romo_handovers_previous_romo_id ON public.order_romo_handovers USING btree (previous_romo_id);

--
-- Name: ix_orders_accepted_romo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_accepted_romo_id ON public.orders USING btree (accepted_romo_id);

--
-- Name: ix_orders_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_created_at ON public.orders USING btree (created_at DESC);

--
-- Name: ix_orders_handover_proposed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_handover_proposed_by ON public.orders USING btree (handover_proposed_by);

--
-- Name: ix_orders_handover_target_romo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_handover_target_romo_id ON public.orders USING btree (handover_target_romo_id);

--
-- Name: ix_orders_kabupaten_kota_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_kabupaten_kota_id ON public.orders USING btree (kabupaten_kota_id);

--
-- Name: ix_orders_keuskupan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_keuskupan_id ON public.orders USING btree (keuskupan_id);

--
-- Name: ix_orders_lingkungan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_lingkungan_id ON public.orders USING btree (lingkungan_id);

--
-- Name: ix_orders_paroki_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_paroki_id ON public.orders USING btree (paroki_id);

--
-- Name: ix_orders_pending_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_pending_created_at ON public.orders USING btree (created_at) WHERE (status = 'PENDING'::public.order_status_enum);

--
-- Name: ix_orders_reschedule_proposed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_reschedule_proposed_by ON public.orders USING btree (reschedule_proposed_by);

--
-- Name: ix_orders_service_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_service_category_id ON public.orders USING btree (service_category_id);

--
-- Name: ix_orders_status_scheduled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_status_scheduled ON public.orders USING btree (status, scheduled_date);

--
-- Name: ix_orders_urgency_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_urgency_level_id ON public.orders USING btree (urgency_level_id);

--
-- Name: ix_orders_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_user_created ON public.orders USING btree (user_id, created_at DESC);

--
-- Name: ix_orders_wilayah_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_orders_wilayah_id ON public.orders USING btree (wilayah_id);

--
-- Name: ix_paroki_keuskupan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_paroki_keuskupan_id ON public.paroki USING btree (keuskupan_id);

--
-- Name: ix_romo_profiles_ordo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_romo_profiles_ordo_id ON public.romo_profiles USING btree (ordo_id);

--
-- Name: ix_user_approvals_approver_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_approvals_approver_user_id ON public.user_approvals USING btree (approver_user_id);

--
-- Name: ix_user_approvals_target_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_approvals_target_user_id ON public.user_approvals USING btree (target_user_id);

--
-- Name: ix_user_profiles_kabupaten_kota_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_profiles_kabupaten_kota_id ON public.user_profiles USING btree (kabupaten_kota_id);

--
-- Name: ix_user_profiles_keuskupan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_profiles_keuskupan_id ON public.user_profiles USING btree (keuskupan_id);

--
-- Name: ix_user_profiles_lingkungan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_profiles_lingkungan_id ON public.user_profiles USING btree (lingkungan_id);

--
-- Name: ix_user_profiles_ordo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_profiles_ordo_id ON public.user_profiles USING btree (ordo_id);

--
-- Name: ix_user_profiles_paroki_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_profiles_paroki_id ON public.user_profiles USING btree (paroki_id);

--
-- Name: ix_user_profiles_wilayah_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_profiles_wilayah_id ON public.user_profiles USING btree (wilayah_id);

--
-- Name: ix_wilayah_paroki_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_wilayah_paroki_id ON public.wilayah USING btree (paroki_id);

--
-- Name: uq_chat_groups_order_item; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_chat_groups_order_item ON public.chat_groups USING btree (order_id, COALESCE(order_item_id, (0)::bigint));

--
-- Name: app_settings trg_app_settings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_app_settings_updated_at BEFORE UPDATE ON public.app_settings FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION public.set_updated_at();

--
-- Name: auth_users trg_auth_users_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_auth_users_updated_at BEFORE UPDATE ON public.auth_users FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION public.set_updated_at();

--
-- Name: chat_groups trg_chat_groups_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_chat_groups_updated_at BEFORE UPDATE ON public.chat_groups FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION public.set_updated_at();

--
-- Name: news_articles trg_news_articles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_articles_updated_at BEFORE UPDATE ON public.news_articles FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION public.set_updated_at();

--
-- Name: news_sources trg_news_sources_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_news_sources_updated_at BEFORE UPDATE ON public.news_sources FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION public.set_updated_at();

--
-- Name: order_items trg_order_items_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_order_items_updated_at BEFORE UPDATE ON public.order_items FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION public.set_updated_at();

--
-- Name: order_reschedules trg_order_reschedules_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_order_reschedules_updated_at BEFORE UPDATE ON public.order_reschedules FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION public.set_updated_at();

--
-- Name: order_romo_handovers trg_order_romo_handovers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_order_romo_handovers_updated_at BEFORE UPDATE ON public.order_romo_handovers FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION public.set_updated_at();

--
-- Name: orders trg_orders_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION public.set_updated_at();

--
-- Name: user_profiles trg_user_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles FOR EACH ROW WHEN ((old.* IS DISTINCT FROM new.*)) EXECUTE FUNCTION public.set_updated_at();

--
-- Name: activity_logs activity_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_logs
    ADD CONSTRAINT activity_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.auth_users(id);

--
-- Name: auth_users auth_users_approval_assigned_to_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_users
    ADD CONSTRAINT auth_users_approval_assigned_to_user_id_fkey FOREIGN KEY (approval_assigned_to_user_id) REFERENCES public.auth_users(id) ON DELETE SET NULL;

--
-- Name: auth_users auth_users_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_users
    ADD CONSTRAINT auth_users_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE RESTRICT;

--
-- Name: chat_group_members chat_group_members_chat_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_group_members
    ADD CONSTRAINT chat_group_members_chat_group_id_fkey FOREIGN KEY (chat_group_id) REFERENCES public.chat_groups(id) ON DELETE CASCADE;

--
-- Name: chat_group_members chat_group_members_last_read_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_group_members
    ADD CONSTRAINT chat_group_members_last_read_message_id_fkey FOREIGN KEY (last_read_message_id) REFERENCES public.chat_messages(id) ON DELETE SET NULL;

--
-- Name: chat_group_members chat_group_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_group_members
    ADD CONSTRAINT chat_group_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.auth_users(id) ON DELETE RESTRICT;

--
-- Name: chat_groups chat_groups_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_groups
    ADD CONSTRAINT chat_groups_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

--
-- Name: chat_groups chat_groups_order_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_groups
    ADD CONSTRAINT chat_groups_order_item_id_fkey FOREIGN KEY (order_item_id) REFERENCES public.order_items(id) ON DELETE CASCADE;

--
-- Name: chat_message_reads chat_message_reads_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_reads
    ADD CONSTRAINT chat_message_reads_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.chat_messages(id) ON DELETE CASCADE;

--
-- Name: chat_message_reads chat_message_reads_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_reads
    ADD CONSTRAINT chat_message_reads_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.auth_users(id) ON DELETE CASCADE;

--
-- Name: chat_messages chat_messages_chat_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_chat_group_id_fkey FOREIGN KEY (chat_group_id) REFERENCES public.chat_groups(id) ON DELETE CASCADE;

--
-- Name: chat_messages chat_messages_reply_to_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_reply_to_message_id_fkey FOREIGN KEY (reply_to_message_id) REFERENCES public.chat_messages(id) ON DELETE SET NULL;

--
-- Name: chat_messages chat_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.auth_users(id) ON DELETE RESTRICT;

--
-- Name: kabupaten_kota kabupaten_kota_provinsi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kabupaten_kota
    ADD CONSTRAINT kabupaten_kota_provinsi_id_fkey FOREIGN KEY (provinsi_id) REFERENCES public.provinsi(id) ON DELETE RESTRICT;

--
-- Name: lingkungan lingkungan_wilayah_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lingkungan
    ADD CONSTRAINT lingkungan_wilayah_id_fkey FOREIGN KEY (wilayah_id) REFERENCES public.wilayah(id) ON DELETE RESTRICT;

--
-- Name: news_article_tags news_article_tags_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_article_tags
    ADD CONSTRAINT news_article_tags_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.news_articles(id) ON DELETE CASCADE;

--
-- Name: news_article_tags news_article_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_article_tags
    ADD CONSTRAINT news_article_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.news_tags(id) ON DELETE CASCADE;

--
-- Name: news_articles news_articles_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_articles
    ADD CONSTRAINT news_articles_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.news_categories(id) ON DELETE SET NULL;

--
-- Name: news_articles news_articles_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_articles
    ADD CONSTRAINT news_articles_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.news_sources(id) ON DELETE SET NULL;

--
-- Name: news_bookmarks news_bookmarks_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_bookmarks
    ADD CONSTRAINT news_bookmarks_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.news_articles(id) ON DELETE CASCADE;

--
-- Name: news_bookmarks news_bookmarks_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_bookmarks
    ADD CONSTRAINT news_bookmarks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.auth_users(id) ON DELETE CASCADE;

--
-- Name: news_scrape_logs news_scrape_logs_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_scrape_logs
    ADD CONSTRAINT news_scrape_logs_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.news_sources(id) ON DELETE CASCADE;

--
-- Name: notifications notifications_chat_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_chat_group_id_fkey FOREIGN KEY (chat_group_id) REFERENCES public.chat_groups(id) ON DELETE CASCADE;

--
-- Name: notifications notifications_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.auth_users(id) ON DELETE CASCADE;

--
-- Name: order_assignments order_assignments_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_assignments
    ADD CONSTRAINT order_assignments_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

--
-- Name: order_assignments order_assignments_romo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_assignments
    ADD CONSTRAINT order_assignments_romo_id_fkey FOREIGN KEY (romo_id) REFERENCES public.auth_users(id) ON DELETE RESTRICT;

--
-- Name: order_items order_items_accepted_romo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_accepted_romo_id_fkey FOREIGN KEY (accepted_romo_id) REFERENCES public.auth_users(id) ON DELETE SET NULL;

--
-- Name: order_items order_items_handover_proposed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_handover_proposed_by_fkey FOREIGN KEY (handover_proposed_by) REFERENCES public.auth_users(id);

--
-- Name: order_items order_items_handover_target_romo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_handover_target_romo_id_fkey FOREIGN KEY (handover_target_romo_id) REFERENCES public.auth_users(id);

--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

--
-- Name: order_items order_items_reschedule_proposed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_reschedule_proposed_by_fkey FOREIGN KEY (reschedule_proposed_by) REFERENCES public.auth_users(id) ON DELETE SET NULL;

--
-- Name: order_monitors order_monitors_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_monitors
    ADD CONSTRAINT order_monitors_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

--
-- Name: order_monitors order_monitors_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_monitors
    ADD CONSTRAINT order_monitors_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.auth_users(id) ON DELETE RESTRICT;

--
-- Name: order_reschedules order_reschedules_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_reschedules
    ADD CONSTRAINT order_reschedules_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.order_items(id) ON DELETE SET NULL;

--
-- Name: order_reschedules order_reschedules_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_reschedules
    ADD CONSTRAINT order_reschedules_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

--
-- Name: order_reschedules order_reschedules_proposed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_reschedules
    ADD CONSTRAINT order_reschedules_proposed_by_fkey FOREIGN KEY (proposed_by) REFERENCES public.auth_users(id) ON DELETE CASCADE;

--
-- Name: order_reschedules order_reschedules_responded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_reschedules
    ADD CONSTRAINT order_reschedules_responded_by_fkey FOREIGN KEY (responded_by) REFERENCES public.auth_users(id) ON DELETE SET NULL;

--
-- Name: order_romo_handovers order_romo_handovers_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_romo_handovers
    ADD CONSTRAINT order_romo_handovers_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.order_items(id) ON DELETE SET NULL;

--
-- Name: order_romo_handovers order_romo_handovers_new_romo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_romo_handovers
    ADD CONSTRAINT order_romo_handovers_new_romo_id_fkey FOREIGN KEY (new_romo_id) REFERENCES public.auth_users(id) ON DELETE SET NULL;

--
-- Name: order_romo_handovers order_romo_handovers_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_romo_handovers
    ADD CONSTRAINT order_romo_handovers_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

--
-- Name: order_romo_handovers order_romo_handovers_previous_romo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_romo_handovers
    ADD CONSTRAINT order_romo_handovers_previous_romo_id_fkey FOREIGN KEY (previous_romo_id) REFERENCES public.auth_users(id) ON DELETE CASCADE;

--
-- Name: orders orders_accepted_romo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_accepted_romo_id_fkey FOREIGN KEY (accepted_romo_id) REFERENCES public.auth_users(id) ON DELETE SET NULL;

--
-- Name: orders orders_handover_proposed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_handover_proposed_by_fkey FOREIGN KEY (handover_proposed_by) REFERENCES public.auth_users(id);

--
-- Name: orders orders_handover_target_romo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_handover_target_romo_id_fkey FOREIGN KEY (handover_target_romo_id) REFERENCES public.auth_users(id);

--
-- Name: orders orders_kabupaten_kota_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_kabupaten_kota_id_fkey FOREIGN KEY (kabupaten_kota_id) REFERENCES public.kabupaten_kota(id) ON DELETE RESTRICT;

--
-- Name: orders orders_keuskupan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_keuskupan_id_fkey FOREIGN KEY (keuskupan_id) REFERENCES public.keuskupan(id) ON DELETE RESTRICT;

--
-- Name: orders orders_lingkungan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_lingkungan_id_fkey FOREIGN KEY (lingkungan_id) REFERENCES public.lingkungan(id) ON DELETE RESTRICT;

--
-- Name: orders orders_paroki_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_paroki_id_fkey FOREIGN KEY (paroki_id) REFERENCES public.paroki(id) ON DELETE RESTRICT;

--
-- Name: orders orders_reschedule_proposed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_reschedule_proposed_by_fkey FOREIGN KEY (reschedule_proposed_by) REFERENCES public.auth_users(id) ON DELETE SET NULL;

--
-- Name: orders orders_service_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_service_category_id_fkey FOREIGN KEY (service_category_id) REFERENCES public.service_categories(id) ON DELETE RESTRICT;

--
-- Name: orders orders_urgency_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_urgency_level_id_fkey FOREIGN KEY (urgency_level_id) REFERENCES public.urgency_levels(id) ON DELETE RESTRICT;

--
-- Name: orders orders_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.auth_users(id) ON DELETE RESTRICT;

--
-- Name: orders orders_wilayah_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_wilayah_id_fkey FOREIGN KEY (wilayah_id) REFERENCES public.wilayah(id) ON DELETE RESTRICT;

--
-- Name: paroki paroki_keuskupan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paroki
    ADD CONSTRAINT paroki_keuskupan_id_fkey FOREIGN KEY (keuskupan_id) REFERENCES public.keuskupan(id) ON DELETE RESTRICT;

--
-- Name: romo_profiles romo_profiles_ordo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.romo_profiles
    ADD CONSTRAINT romo_profiles_ordo_id_fkey FOREIGN KEY (ordo_id) REFERENCES public.ordo(id) ON DELETE SET NULL;

--
-- Name: romo_profiles romo_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.romo_profiles
    ADD CONSTRAINT romo_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.auth_users(id) ON DELETE CASCADE;

--
-- Name: user_approvals user_approvals_approver_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_approvals
    ADD CONSTRAINT user_approvals_approver_user_id_fkey FOREIGN KEY (approver_user_id) REFERENCES public.auth_users(id) ON DELETE RESTRICT;

--
-- Name: user_approvals user_approvals_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_approvals
    ADD CONSTRAINT user_approvals_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.auth_users(id) ON DELETE CASCADE;

--
-- Name: user_devices user_devices_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_devices
    ADD CONSTRAINT user_devices_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.auth_users(id) ON DELETE CASCADE;

--
-- Name: user_profiles user_profiles_kabupaten_kota_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_kabupaten_kota_id_fkey FOREIGN KEY (kabupaten_kota_id) REFERENCES public.kabupaten_kota(id) ON DELETE SET NULL;

--
-- Name: user_profiles user_profiles_keuskupan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_keuskupan_id_fkey FOREIGN KEY (keuskupan_id) REFERENCES public.keuskupan(id) ON DELETE SET NULL;

--
-- Name: user_profiles user_profiles_lingkungan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_lingkungan_id_fkey FOREIGN KEY (lingkungan_id) REFERENCES public.lingkungan(id) ON DELETE SET NULL;

--
-- Name: user_profiles user_profiles_ordo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_ordo_id_fkey FOREIGN KEY (ordo_id) REFERENCES public.ordo(id) ON DELETE SET NULL;

--
-- Name: user_profiles user_profiles_paroki_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_paroki_id_fkey FOREIGN KEY (paroki_id) REFERENCES public.paroki(id) ON DELETE SET NULL;

--
-- Name: user_profiles user_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.auth_users(id) ON DELETE CASCADE;

--
-- Name: user_profiles user_profiles_wilayah_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_wilayah_id_fkey FOREIGN KEY (wilayah_id) REFERENCES public.wilayah(id) ON DELETE SET NULL;

--
-- Name: wilayah wilayah_paroki_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wilayah
    ADD CONSTRAINT wilayah_paroki_id_fkey FOREIGN KEY (paroki_id) REFERENCES public.paroki(id) ON DELETE RESTRICT;

--
-- PostgreSQL database dump complete
--
