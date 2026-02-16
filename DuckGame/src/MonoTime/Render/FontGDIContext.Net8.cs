#if DUCKGAME_NET8
using System.Collections.Generic;

namespace DuckGame
{
    internal static class FontGDIContext
    {
        public static Dictionary<string, RasterFont.Data> _fontDatas = new Dictionary<string, RasterFont.Data>();

        public static string GetName(string pFont)
        {
            if (string.IsNullOrWhiteSpace(pFont))
            {
                return null;
            }

            return pFont;
        }

        public static RasterFont.Data CreateRasterFontData(string pFont, float pSize)
        {
            string name = GetName(pFont) ?? "smallFont";
            string key = name + "#" + pSize.ToString();

            if (_fontDatas.TryGetValue(key, out RasterFont.Data existing))
            {
                return existing;
            }

            RasterFont.Data data = new RasterFont.Data()
            {
                name = name,
                fontSize = pSize,
                fontHeight = pSize,
                characters = new List<BitmapFont_CharacterInfo>(),
                colors = null,
                colorsWidth = 0,
                colorsHeight = 0
            };

            _fontDatas[key] = data;
            return data;
        }
    }
}
#endif
