#if DUCKGAME_NET10
using System.Collections.Generic;

namespace DuckGame
{
    public class Speech
    {
        public object _speech;

        public void Initialize()
        {
        }

        public object speech => null;

        public void Say(string pString)
        {
        }

        public void StopSaying()
        {
        }

        public void SetSayVoice(string pName)
        {
        }

        public List<string> GetSayVoices()
        {
            return new List<string>();
        }

        public void ApplyTTSSettings()
        {
        }

        public void SetOutputToDefaultAudioDevice()
        {
        }
    }
}
#endif
