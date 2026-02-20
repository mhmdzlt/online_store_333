-- Add optional coordinates to donations for nearby filtering.
ALTER TABLE public.donations
ADD COLUMN IF NOT EXISTS latitude double precision,
ADD COLUMN IF NOT EXISTS longitude double precision;

-- Optional helper indexes if you plan server-side geo filtering later.
-- CREATE INDEX IF NOT EXISTS idx_donations_latitude ON public.donations (latitude);
-- CREATE INDEX IF NOT EXISTS idx_donations_longitude ON public.donations (longitude);
