
-- SQL Initialization for Piu Gift Corner

-- Table: users (Custom profiles)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  display_name TEXT,
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Function to check if current user is admin
CREATE OR REPLACE FUNCTION is_admin() 
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    SELECT role = 'admin' 
    FROM public.users 
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Alter existing products table to ensure new columns exist (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='products') THEN
        -- rename image to image_url if image_url doesn't exist but image does
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='image_url') THEN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='image') THEN
                DROP VIEW IF EXISTS featured_products;
                ALTER TABLE public.products RENAME COLUMN image TO image_url;
            ELSE
                ALTER TABLE public.products ADD COLUMN image_url TEXT;
            END IF;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='video_url') THEN
            ALTER TABLE public.products ADD COLUMN video_url TEXT;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='is_featured') THEN
            ALTER TABLE public.products ADD COLUMN is_featured BOOLEAN DEFAULT false;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='customizable') THEN
            ALTER TABLE public.products ADD COLUMN customizable BOOLEAN DEFAULT false;
        END IF;
    END IF;
END $$;

-- Table: products
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL NOT NULL,
  image_url TEXT,
  video_url TEXT,
  categories TEXT[],
  rating DECIMAL DEFAULT 4.5,
  reviews_count INTEGER DEFAULT 0,
  stock INTEGER DEFAULT 10,
  is_featured BOOLEAN DEFAULT false,
  customizable BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Table: orders
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  total DECIMAL NOT NULL,
  status TEXT DEFAULT 'processing',
  shipping_details JSONB,
  items JSONB,
  payment_method TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Policies for users
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
CREATE POLICY "Users can view their own profile" 
ON users FOR SELECT 
TO authenticated
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON users;
CREATE POLICY "Users can insert their own profile" 
ON users FOR INSERT 
TO authenticated
WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile (restricted)" ON users;
CREATE POLICY "Users can update their own profile (restricted)" 
ON users FOR UPDATE 
TO authenticated
USING (auth.uid() = id)
WITH CHECK (role = 'user'); -- Prevent self-promotion

DROP POLICY IF EXISTS "Admins can view all users" ON users;
CREATE POLICY "Admins can view all users"
ON users FOR SELECT
TO authenticated
USING (is_admin());

-- Policies for products
DROP POLICY IF EXISTS "Public products are viewable by everyone" ON products;
CREATE POLICY "Public products are viewable by everyone" 
ON products FOR SELECT 
USING (true);

DROP POLICY IF EXISTS "Only admins can manage products" ON products;
CREATE POLICY "Only admins can manage products" 
ON products FOR ALL 
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- Create a view for featured products
DROP VIEW IF EXISTS featured_products;
CREATE VIEW featured_products
WITH (security_invoker = on) AS
SELECT * FROM products WHERE is_featured = true;

-- Policies for orders
DROP POLICY IF EXISTS "Users can view their own orders" ON orders;
CREATE POLICY "Users can view their own orders" 
ON orders FOR SELECT 
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create their own orders" ON orders;
CREATE POLICY "Users can create their own orders" 
ON orders FOR INSERT 
TO authenticated
WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Create product-assets storage bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('product-assets', 'product-assets', true)
ON CONFLICT (id) DO NOTHING;

-- Allow public access to product-assets
DROP POLICY IF EXISTS "product-assets public read" ON storage.objects;
CREATE POLICY "product-assets public read" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'product-assets');

DROP POLICY IF EXISTS "product-assets admin all" ON storage.objects;
CREATE POLICY "product-assets admin all" 
ON storage.objects FOR ALL 
TO authenticated
USING (bucket_id = 'product-assets' AND (SELECT is_admin()));

-- Add some sample products
-- Demo products removed by request

