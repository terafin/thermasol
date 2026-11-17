from pathlib import Path
import unittest,re
D=Path(__file__).parent
class Scope(unittest.TestCase):
 def test_only_idle_audio_light_frames(self):
  s=(D/'idle_frames.h').read_text()
  self.assertNotRegex(s,r'0x0[eEfF]|0x17')
  self.assertIn('out[2].data[1]=0x5f',s)
  self.assertIn('out[0].data[1]=0xb5',s)
  self.assertIn('out[1].data[1]=0xb4',s)
 def test_current_boot_fresh_idle_required(self):
  s=(D/'idle_can.c').read_text()
  self.assertIn('now-last>5000',s);self.assertIn('strcmp(boot,liveboot)',s)
  self.assertIn('strcmp(media,"playing")',s);self.assertIn('strcmp(state,"dim")',s)
  self.assertNotIn('system(',s);self.assertNotIn('exec',s);self.assertIn('flock(lock,LOCK_EX|LOCK_NB)',s);self.assertIn('SO_SNDTIMEO',s);self.assertIn('O_NOFOLLOW',s)
 def test_write_ahead_journal_and_transition_retry(self):
  s=(D/'idle_can.c').read_text()
  self.assertLess(s.index('if(atomic_file(BASE".owned",resume?'),s.index('for(int i=0;i<count;i++)'))
  self.assertIn('fsync(parent)',s)
  b=(D.parent/'supervisor/src/PeripheralBridge.java').read_text()
  self.assertIn('action.equals(lastAttempt)',b)
  self.assertIn('accepted=null;',b)
 def test_no_service_bind_or_focus_request(self):
  s=(D.parent/'supervisor/src/PeripheralBridge.java').read_text()
  self.assertNotIn('"broadcast"',s);self.assertNotIn('bindService(',s)
if __name__=='__main__':unittest.main()
