#if DUCKGAME_NET10
using System;
using System.IO;
using XnaToFna.ProxyForms;

namespace System.Windows.Forms
{
    public delegate void ThreadExceptionEventHandler(object sender, ThreadExceptionEventArgs e);

    public sealed class ThreadExceptionEventArgs : EventArgs
    {
        public Exception Exception { get; }

        public ThreadExceptionEventArgs(Exception exception)
        {
            Exception = exception;
        }
    }

    public static class Application
    {
        public static event ThreadExceptionEventHandler ThreadException;

        public static string ExecutablePath => XnaToFna.ProxyForms.Application.ExecutablePath;

        public static void Exit() => Environment.Exit(0);

        public static void RaiseThreadException(Exception exception)
        {
            ThreadException?.Invoke(null, new ThreadExceptionEventArgs(exception));
        }
    }

    public static class MessageBox
    {
        public static DialogResult Show(string text)
        {
            Console.WriteLine(text);
            return DialogResult.OK;
        }
    }

    public enum DialogResult
    {
        None = 0,
        OK = 1,
        Cancel = 2
    }

    public struct Message
    {
        public IntPtr HWnd { get; set; }
        public int Msg { get; set; }
        public IntPtr WParam { get; set; }
        public IntPtr LParam { get; set; }
        public IntPtr Result { get; set; }
    }

    public class Form : XnaToFna.ProxyForms.Form
    {
        public virtual DialogResult ShowDialog()
        {
            return DialogResult.Cancel;
        }

        protected virtual void WndProc(ref Message m)
        {
        }
    }

    public class OpenFileDialog
    {
        public string Filter { get; set; } = string.Empty;

        public string FileName { get; set; } = string.Empty;

        public DialogResult ShowDialog()
        {
            return DialogResult.Cancel;
        }
    }

    public class SaveFileDialog
    {
        public bool AddExtension { get; set; }

        public string DefaultExt { get; set; } = string.Empty;

        public string Filter { get; set; } = string.Empty;

        public string FileName { get; set; } = string.Empty;

        public DialogResult ShowDialog()
        {
            return DialogResult.Cancel;
        }
    }

    public class RichTextBox
    {
        public System.Drawing.Color SelectionColor { get; set; }

        public string Text { get; private set; } = string.Empty;

        public void AppendText(string value)
        {
            Text += value;
        }

        public void SaveFile(string path)
        {
            File.WriteAllText(path, Text);
        }
    }
}
#endif
