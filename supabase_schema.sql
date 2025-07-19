-- Tava App Database Schema
-- Food sharing app with restaurants and homemade meals

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Create custom types
CREATE TYPE meal_type AS ENUM ('restaurant', 'homemade');
CREATE TYPE meal_privacy AS ENUM ('public', 'friends_only', 'private');
CREATE TYPE collaboration_status AS ENUM ('active', 'completed', 'cancelled');

-- Users table (extends Supabase auth.users)
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    username VARCHAR(30) UNIQUE NOT NULL,
    display_name VARCHAR(100),
    bio TEXT,
    avatar_url TEXT,
    location_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User follows (social features)
CREATE TABLE public.user_follows (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    follower_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    following_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(follower_id, following_id),
    CHECK (follower_id != following_id)
);

-- Restaurants table (from Google Places API data)
CREATE TABLE public.restaurants (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    google_place_id VARCHAR(255) UNIQUE,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    country VARCHAR(50),
    phone VARCHAR(20),
    location GEOGRAPHY(POINT),
    rating DECIMAL(2,1),
    price_range INTEGER, -- 1-4 ($-$$$$)
    categories JSONB,
    hours JSONB,
    google_maps_url TEXT,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Meals table (both restaurant and homemade)
CREATE TABLE public.meals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    restaurant_id UUID REFERENCES public.restaurants(id) ON DELETE SET NULL,
    meal_type meal_type NOT NULL,
    title VARCHAR(255),
    description TEXT,
    ingredients TEXT, -- For homemade meals
    tags TEXT[], -- Array of tags
    privacy meal_privacy DEFAULT 'public',
    location GEOGRAPHY(POINT), -- For restaurant meals, copied from restaurant
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    cost DECIMAL(10,2),
    eaten_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Collaborative meals (shared dining experiences)
CREATE TABLE public.collaborative_meals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    creator_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    restaurant_id UUID REFERENCES public.restaurants(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status collaboration_status DEFAULT 'active',
    location GEOGRAPHY(POINT),
    scheduled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Collaborative meal participants
CREATE TABLE public.collaborative_meal_participants (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    collaborative_meal_id UUID REFERENCES public.collaborative_meals(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(collaborative_meal_id, user_id)
);

-- Photos table (for meals)
CREATE TABLE public.photos (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    meal_id UUID REFERENCES public.meals(id) ON DELETE CASCADE,
    collaborative_meal_id UUID REFERENCES public.collaborative_meals(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL, -- Path in Supabase storage
    url TEXT NOT NULL, -- Public URL
    alt_text TEXT,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CHECK (meal_id IS NOT NULL OR collaborative_meal_id IS NOT NULL)
);

-- Bookmarks/Favorites
CREATE TABLE public.bookmarks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    meal_id UUID REFERENCES public.meals(id) ON DELETE CASCADE,
    restaurant_id UUID REFERENCES public.restaurants(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CHECK (meal_id IS NOT NULL OR restaurant_id IS NOT NULL),
    UNIQUE(user_id, meal_id),
    UNIQUE(user_id, restaurant_id)
);

-- Meal reactions/likes
CREATE TABLE public.meal_reactions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    meal_id UUID REFERENCES public.meals(id) ON DELETE CASCADE,
    reaction_type VARCHAR(20) DEFAULT 'like', -- like, love, yum, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, meal_id)
);

-- Create indexes for performance
CREATE INDEX idx_meals_user_id ON public.meals(user_id);
CREATE INDEX idx_meals_created_at ON public.meals(created_at DESC);
CREATE INDEX idx_meals_location ON public.meals USING GIST(location);
CREATE INDEX idx_meals_meal_type ON public.meals(meal_type);
CREATE INDEX idx_meals_privacy ON public.meals(privacy);
CREATE INDEX idx_restaurants_location ON public.restaurants USING GIST(location);
CREATE INDEX idx_restaurants_google_place_id ON public.restaurants(google_place_id);
CREATE INDEX idx_photos_meal_id ON public.photos(meal_id);
CREATE INDEX idx_user_follows_follower ON public.user_follows(follower_id);
CREATE INDEX idx_user_follows_following ON public.user_follows(following_id);
CREATE INDEX idx_bookmarks_user_id ON public.bookmarks(user_id);

-- Row Level Security (RLS) Policies

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collaborative_meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collaborative_meal_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_reactions ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view public profiles" ON public.users
    FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- User follows policies
CREATE POLICY "Users can view all follows" ON public.user_follows
    FOR SELECT USING (true);

CREATE POLICY "Users can manage own follows" ON public.user_follows
    FOR ALL USING (auth.uid() = follower_id);

-- Restaurants policies (public read-only)
CREATE POLICY "Anyone can view restaurants" ON public.restaurants
    FOR SELECT USING (true);

CREATE POLICY "Only authenticated users can insert restaurants" ON public.restaurants
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Meals policies
CREATE POLICY "Users can view public meals" ON public.meals
    FOR SELECT USING (
        privacy = 'public' OR 
        user_id = auth.uid() OR
        (privacy = 'friends_only' AND user_id IN (
            SELECT following_id FROM public.user_follows WHERE follower_id = auth.uid()
        ))
    );

CREATE POLICY "Users can manage own meals" ON public.meals
    FOR ALL USING (auth.uid() = user_id);

-- Collaborative meals policies
CREATE POLICY "Users can view collaborative meals they're part of" ON public.collaborative_meals
    FOR SELECT USING (
        creator_id = auth.uid() OR
        id IN (SELECT collaborative_meal_id FROM public.collaborative_meal_participants WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can manage collaborative meals they created" ON public.collaborative_meals
    FOR ALL USING (auth.uid() = creator_id);

-- Collaborative meal participants policies
CREATE POLICY "Participants can view collaborative meal participants" ON public.collaborative_meal_participants
    FOR SELECT USING (
        user_id = auth.uid() OR
        collaborative_meal_id IN (
            SELECT id FROM public.collaborative_meals WHERE creator_id = auth.uid()
        )
    );

CREATE POLICY "Users can join collaborative meals" ON public.collaborative_meal_participants
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave collaborative meals" ON public.collaborative_meal_participants
    FOR DELETE USING (auth.uid() = user_id);

-- Photos policies
CREATE POLICY "Users can view photos of accessible meals" ON public.photos
    FOR SELECT USING (
        meal_id IN (SELECT id FROM public.meals) OR
        collaborative_meal_id IN (SELECT id FROM public.collaborative_meals) OR
        user_id = auth.uid()
    );

CREATE POLICY "Users can manage own photos" ON public.photos
    FOR ALL USING (auth.uid() = user_id);

-- Bookmarks policies
CREATE POLICY "Users can manage own bookmarks" ON public.bookmarks
    FOR ALL USING (auth.uid() = user_id);

-- Meal reactions policies
CREATE POLICY "Users can view reactions on accessible meals" ON public.meal_reactions
    FOR SELECT USING (
        meal_id IN (SELECT id FROM public.meals)
    );

CREATE POLICY "Users can manage own reactions" ON public.meal_reactions
    FOR ALL USING (auth.uid() = user_id);

-- Functions for common queries

-- Get user's feed (meals from followed users)
CREATE OR REPLACE FUNCTION get_user_feed(user_uuid UUID, limit_count INTEGER DEFAULT 20, offset_count INTEGER DEFAULT 0)
RETURNS TABLE (
    meal_id UUID,
    user_id UUID,
    username VARCHAR,
    display_name VARCHAR,
    avatar_url TEXT,
    meal_title VARCHAR,
    meal_description TEXT,
    meal_type meal_type,
    restaurant_name VARCHAR,
    location GEOGRAPHY,
    rating INTEGER,
    eaten_at TIMESTAMP WITH TIME ZONE,
    photo_urls TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id as meal_id,
        m.user_id,
        u.username,
        u.display_name,
        u.avatar_url,
        m.title as meal_title,
        m.description as meal_description,
        m.meal_type,
        r.name as restaurant_name,
        m.location,
        m.rating,
        m.eaten_at,
        ARRAY_AGG(p.url) as photo_urls
    FROM public.meals m
    JOIN public.users u ON u.id = m.user_id
    LEFT JOIN public.restaurants r ON r.id = m.restaurant_id
    LEFT JOIN public.photos p ON p.meal_id = m.id
    WHERE m.user_id IN (
        SELECT following_id FROM public.user_follows WHERE follower_id = user_uuid
        UNION SELECT user_uuid -- Include own meals
    )
    AND (m.privacy = 'public' OR m.privacy = 'friends_only')
    GROUP BY m.id, u.id, r.name
    ORDER BY m.eaten_at DESC
    LIMIT limit_count OFFSET offset_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get nearby meals for map view
CREATE OR REPLACE FUNCTION get_nearby_meals(
    center_lat FLOAT, 
    center_lng FLOAT, 
    radius_meters INTEGER DEFAULT 5000,
    user_uuid UUID DEFAULT NULL
)
RETURNS TABLE (
    meal_id UUID,
    user_id UUID,
    username VARCHAR,
    display_name VARCHAR,
    meal_title VARCHAR,
    meal_type meal_type,
    restaurant_name VARCHAR,
    latitude FLOAT,
    longitude FLOAT,
    eaten_at TIMESTAMP WITH TIME ZONE,
    primary_photo_url TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id as meal_id,
        m.user_id,
        u.username,
        u.display_name,
        m.title as meal_title,
        m.meal_type,
        r.name as restaurant_name,
        ST_Y(m.location::geometry) as latitude,
        ST_X(m.location::geometry) as longitude,
        m.eaten_at,
        p.url as primary_photo_url
    FROM public.meals m
    JOIN public.users u ON u.id = m.user_id
    LEFT JOIN public.restaurants r ON r.id = m.restaurant_id
    LEFT JOIN public.photos p ON p.meal_id = m.id AND p.is_primary = true
    WHERE m.meal_type = 'restaurant' -- Only restaurant meals on map
    AND m.privacy = 'public'
    AND m.location IS NOT NULL
    AND ST_DWithin(
        m.location,
        ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::geography,
        radius_meters
    )
    AND (user_uuid IS NULL OR m.user_id IN (
        SELECT following_id FROM public.user_follows WHERE follower_id = user_uuid
        UNION SELECT user_uuid
    ))
    ORDER BY m.eaten_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_restaurants_updated_at BEFORE UPDATE ON public.restaurants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_meals_updated_at BEFORE UPDATE ON public.meals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_collaborative_meals_updated_at BEFORE UPDATE ON public.collaborative_meals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column(); 

-- Storage Configuration
-- Note: Run these commands in the Supabase Dashboard > Storage

-- 1. Create storage bucket 'meal-photos' (if not exists)
-- INSERT INTO storage.buckets (id, name, public) 
-- VALUES ('meal-photos', 'meal-photos', true);

-- 2. Set up Row Level Security policies for storage
-- Allow authenticated users to upload photos
-- CREATE POLICY "Users can upload meal photos" ON storage.objects
-- FOR INSERT WITH CHECK (
--   bucket_id = 'meal-photos' 
--   AND auth.uid()::text = (storage.foldername(name))[1]
-- );

-- Allow users to view all public photos
-- CREATE POLICY "Anyone can view meal photos" ON storage.objects
-- FOR SELECT USING (bucket_id = 'meal-photos');

-- Allow users to delete their own photos
-- CREATE POLICY "Users can delete own meal photos" ON storage.objects
-- FOR DELETE USING (
--   bucket_id = 'meal-photos' 
--   AND auth.uid()::text = (storage.foldername(name))[1]
-- ); 