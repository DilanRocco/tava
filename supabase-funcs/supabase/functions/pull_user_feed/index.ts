// supabase/functions/get-user-feed/index.ts

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface FeedParams {
  user_uuid: string
  limit_count?: number
  offset_count?: number
}

interface FeedMealData {
  meal_id: string
  user_id: string
  username: string
  display_name?: string
  avatar_url?: string
  meal_title?: string
  meal_description?: string
  meal_type: string
  location_text: string
  tags: string[]
  rating?: number
  eaten_at: string
  likes_count: number
  comments_count: number
  bookmarks_count: number
  primary_photo_file_path?: string
  photo_url?: string 
  user_has_liked: boolean
  user_has_bookmarked: boolean
}

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🔑 Edge Function called')
    
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Get request parameters
    const { user_uuid, limit_count = 20, offset_count = 0 }: FeedParams = await req.json()
    console.log('🔑 Request params:', { user_uuid, limit_count, offset_count })

    // Get the raw feed data using your existing RPC function
    console.log('🔑 Calling RPC function get_user_feed')
    const { data: feedData, error: feedError } = await supabaseClient.rpc('get_user_feed', {
      user_uuid,
      limit_count,
      offset_count
    })

    if (feedError) {
      console.error('🔑 RPC Error:', feedError)
      throw feedError
    }

    console.log('🔑 Feed data received:', feedData?.length || 0, 'items')

    // Generate signed URLs for photos
    const feedWithUrls: FeedMealData[] = await Promise.all(
      feedData.map(async (meal: FeedMealData) => {
        if (meal.primary_photo_file_path) {
          try {
            const { data: signedUrlData } = await supabaseClient.storage
              .from('meal-photos')
              .createSignedUrl(meal.primary_photo_file_path, 3600) // 1 hour expiry
            
            return {
              ...meal,
              photo_url: signedUrlData?.signedUrl || null
            }
          } catch (error) {
            console.error(`Failed to generate signed URL for ${meal.primary_photo_file_path}:`, error)
            return {
              ...meal,
              photo_url: null
            }
          }
        }
        
        return {
          ...meal,
          photo_url: null
        }
      })
    )

    console.log('🔑 Returning response with', feedWithUrls.length, 'items')
    return new Response(
      JSON.stringify(feedWithUrls),
      { 
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json' 
        } 
      }
    )

  } catch (error) {
    console.error('Error in get-user-feed function:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500,
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json' 
        }
      }
    )
  }
})