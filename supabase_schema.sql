-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.bookmarks (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid,
  meal_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT bookmarks_pkey PRIMARY KEY (id),
  CONSTRAINT bookmarks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT bookmarks_meal_id_fkey FOREIGN KEY (meal_id) REFERENCES public.meals(id)
);
CREATE TABLE public.collaborative_meal_participants (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  collaborative_meal_id uuid,
  user_id uuid,
  joined_at timestamp with time zone DEFAULT now(),
  CONSTRAINT collaborative_meal_participants_pkey PRIMARY KEY (id),
  CONSTRAINT collaborative_meal_participants_collaborative_meal_id_fkey FOREIGN KEY (collaborative_meal_id) REFERENCES public.collaborative_meals(id),
  CONSTRAINT collaborative_meal_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.collaborative_meals (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  creator_id uuid,
  restaurant_id uuid,
  title character varying NOT NULL,
  description text,
  status USER-DEFINED DEFAULT 'active'::collaboration_status,
  location USER-DEFINED,
  scheduled_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT collaborative_meals_pkey PRIMARY KEY (id),
  CONSTRAINT collaborative_meals_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id),
  CONSTRAINT collaborative_meals_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id)
);
CREATE TABLE public.comment_reactions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid,
  comment_id uuid,
  reaction_type character varying DEFAULT 'like'::character varying,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT comment_reactions_pkey PRIMARY KEY (id),
  CONSTRAINT comment_reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT comment_reactions_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.meal_comments(id)
);
CREATE TABLE public.meal_comments (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  meal_id uuid,
  user_id uuid,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  parent_comment_id uuid,
  CONSTRAINT meal_comments_pkey PRIMARY KEY (id),
  CONSTRAINT meal_comments_meal_id_fkey FOREIGN KEY (meal_id) REFERENCES public.meals(id),
  CONSTRAINT meal_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT meal_comments_parent_comment_id_fkey FOREIGN KEY (parent_comment_id) REFERENCES public.meal_comments(id)
);
CREATE TABLE public.meal_reactions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid,
  meal_id uuid,
  reaction_type character varying DEFAULT 'like'::character varying,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT meal_reactions_pkey PRIMARY KEY (id),
  CONSTRAINT meal_reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT meal_reactions_meal_id_fkey FOREIGN KEY (meal_id) REFERENCES public.meals(id)
);
CREATE TABLE public.meals (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid,
  restaurant_id uuid,
  meal_type USER-DEFINED NOT NULL,
  title character varying,
  description text,
  ingredients text,
  tags ARRAY,
  privacy USER-DEFINED DEFAULT 'public'::meal_privacy,
  location USER-DEFINED,
  rating integer CHECK (rating >= 1 AND rating <= 5),
  cost numeric,
  eaten_at timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  status USER-DEFINED DEFAULT 'published'::meal_status,
  last_activity_at timestamp with time zone DEFAULT now(),
  CONSTRAINT meals_pkey PRIMARY KEY (id),
  CONSTRAINT meals_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT meals_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id)
);
CREATE TABLE public.photos (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  meal_id uuid,
  collaborative_meal_id uuid,
  user_id uuid,
  storage_path text NOT NULL,
  url text NOT NULL,
  alt_text text,
  is_primary boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  course text,
  CONSTRAINT photos_pkey PRIMARY KEY (id),
  CONSTRAINT photos_meal_id_fkey FOREIGN KEY (meal_id) REFERENCES public.meals(id),
  CONSTRAINT photos_collaborative_meal_id_fkey FOREIGN KEY (collaborative_meal_id) REFERENCES public.collaborative_meals(id),
  CONSTRAINT photos_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.restaurants (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  google_place_id character varying UNIQUE,
  name character varying NOT NULL,
  address text,
  city character varying,
  state character varying,
  postal_code character varying,
  country character varying,
  phone character varying,
  location USER-DEFINED,
  rating numeric,
  price_range integer,
  categories jsonb,
  hours jsonb,
  google_maps_url text,
  image_url text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT restaurants_pkey PRIMARY KEY (id)
);
CREATE TABLE public.spatial_ref_sys (
  srid integer NOT NULL CHECK (srid > 0 AND srid <= 998999),
  auth_name character varying,
  auth_srid integer,
  srtext character varying,
  proj4text character varying,
  CONSTRAINT spatial_ref_sys_pkey PRIMARY KEY (srid)
);
CREATE TABLE public.user_follows (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  follower_id uuid,
  following_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_follows_pkey PRIMARY KEY (id),
  CONSTRAINT user_follows_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.users(id),
  CONSTRAINT user_follows_following_id_fkey FOREIGN KEY (following_id) REFERENCES public.users(id)
);
CREATE TABLE public.users (
  id uuid NOT NULL,
  username character varying NOT NULL UNIQUE,
  display_name character varying,
  bio text,
  avatar_url text,
  location_enabled boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);