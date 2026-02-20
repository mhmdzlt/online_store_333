-- Nearby donations RPC (no extensions required).
-- Uses Haversine formula in SQL.

CREATE OR REPLACE FUNCTION public.get_nearby_donations(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision,
  p_city text DEFAULT NULL,
  p_status text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  title text,
  description text,
  city text,
  area text,
  status text,
  image_urls text[],
  created_at timestamptz,
  latitude double precision,
  longitude double precision
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    d.id,
    d.title,
    d.description,
    d.city,
    d.area,
    d.status,
    d.image_urls,
    d.created_at,
    d.latitude,
    d.longitude
  FROM public.donations d
  WHERE d.latitude IS NOT NULL
    AND d.longitude IS NOT NULL
    AND (p_city IS NULL OR p_city = '' OR d.city = p_city)
    AND (p_status IS NULL OR p_status = '' OR d.status = p_status)
    AND (
      6371 * 2 * ASIN(
        SQRT(
          POWER(SIN(RADIANS((d.latitude - p_lat) / 2)), 2) +
          COS(RADIANS(p_lat)) * COS(RADIANS(d.latitude)) *
          POWER(SIN(RADIANS((d.longitude - p_lng) / 2)), 2)
        )
      )
    ) <= p_radius_km
  ORDER BY d.created_at DESC;
$$;
