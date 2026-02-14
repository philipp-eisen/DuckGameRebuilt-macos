#if DUCKGAME_NET8
using Microsoft.Xna.Framework.Graphics;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;
using System;
using System.IO;
using XnaToFna;

namespace DuckGame
{
    internal static class TextureConverter
    {
        public static bool lastLoadResultedInResize = false;
        private static Vec2 _maxDimensions = Vec2.Zero;

        public static Color FromNonPremultiplied(int r, int g, int b, int a)
        {
            return new Color(r * a / 255, g * a / 255, b * a / 255, a);
        }

        private static Image<Rgba32> PrepareImage(Image<Rgba32> image, bool process)
        {
            lastLoadResultedInResize = false;

            if (_maxDimensions != Vec2.Zero)
            {
                float maxW = _maxDimensions.x;
                float maxH = _maxDimensions.y;
                float scale = Math.Min(maxW / image.Width, maxH / image.Height);

                if (maxW < image.Width || maxH < image.Height)
                {
                    lastLoadResultedInResize = true;
                    int newW = Math.Max(1, (int)Math.Floor(image.Width * scale));
                    int newH = Math.Max(1, (int)Math.Floor(image.Height * scale));
                    image.Mutate(x => x.Resize(newW, newH));
                }
            }

            if (process)
            {
                image.ProcessPixelRows(accessor =>
                {
                    for (int y = 0; y < accessor.Height; y++)
                    {
                        Span<Rgba32> row = accessor.GetRowSpan(y);
                        for (int x = 0; x < row.Length; x++)
                        {
                            ref Rgba32 px = ref row[x];
                            if (px.R == 255 && px.G == 0 && px.B == 255)
                            {
                                px.A = 0;
                            }
                        }
                    }
                });
            }

            return image;
        }

        private static Texture2D LoadTexture(GraphicsDevice device, Image<Rgba32> image, bool process)
        {
            PrepareImage(image, process);

            using (MemoryStream ms = new MemoryStream())
            {
                image.SaveAsPng(ms);
                ms.Seek(0, SeekOrigin.Begin);
                Texture2D texture = Texture2D.FromStream(device, ms);

                Color[] buffer = new Color[texture.Width * texture.Height];
                texture.GetData(buffer);
                for (int i = 0; i < buffer.Length; i++)
                {
                    buffer[i] = FromNonPremultiplied(buffer[i].r, buffer[i].g, buffer[i].b, buffer[i].a);
                }

                texture.SetData(buffer);
                return texture;
            }
        }

        internal static PNGData LoadPNGDataWithPinkAwesomeness(Stream stream, bool process)
        {
            using (Image<Rgba32> image = Image.Load<Rgba32>(stream))
            {
                PrepareImage(image, process);

                int[] data = new int[image.Width * image.Height];
                int index = 0;
                image.ProcessPixelRows(accessor =>
                {
                    for (int y = 0; y < accessor.Height; y++)
                    {
                        Span<Rgba32> row = accessor.GetRowSpan(y);
                        for (int x = 0; x < row.Length; x++)
                        {
                            Rgba32 px = row[x];
                            Color c = FromNonPremultiplied(px.R, px.G, px.B, px.A);
                            data[index++] = unchecked((int)c.PackedValue);
                        }
                    }
                });

                return new PNGData
                {
                    data = data,
                    width = image.Width,
                    height = image.Height
                };
            }
        }

        internal static Texture2D LoadPNGWithPinkAwesomeness(GraphicsDevice device, Stream stream, bool process)
        {
            using (Image<Rgba32> image = Image.Load<Rgba32>(stream))
            {
                return LoadTexture(device, image, process);
            }
        }

        internal static Texture2D LoadPNGWithPinkAwesomeness(GraphicsDevice device, string fileName, bool process)
        {
            if (Program.IsLinuxD || Program.isLinux)
            {
                fileName = XnaToFnaHelper.GetActualCaseForFileName(XnaToFnaHelper.FixPath(fileName), true);
            }

            try
            {
                using (FileStream stream = File.OpenRead(fileName))
                {
                    return LoadPNGWithPinkAwesomeness(device, stream, process);
                }
            }
            catch
            {
                return null;
            }
        }

        internal static Texture2D LoadPNGWithPinkAwesomenessAndMaxDimensions(
          GraphicsDevice device,
          string fileName,
          bool process,
          Vec2 maxDimensions)
        {
            _maxDimensions = maxDimensions;
            try
            {
                return LoadPNGWithPinkAwesomeness(device, fileName, process);
            }
            finally
            {
                _maxDimensions = Vec2.Zero;
            }
        }

        internal static PNGData LoadPNGDataWithPinkAwesomeness(GraphicsDevice device, string fileName, bool process)
        {
            if (Program.IsLinuxD || Program.isLinux)
            {
                fileName = XnaToFnaHelper.GetActualCaseForFileName(XnaToFnaHelper.FixPath(fileName), true);
            }

            using (FileStream stream = File.OpenRead(fileName))
            {
                return LoadPNGDataWithPinkAwesomeness(stream, process);
            }
        }
    }
}
#endif
