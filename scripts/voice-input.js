(function() {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SpeechRecognition) {
    console.warn('Web Speech API not supported');
    return;
  }

  let recognitionSingleton = null;
  let isListening = false;

  function getRecognition() {
    if (recognitionSingleton) return recognitionSingleton;
    const r = new SpeechRecognition();
    r.continuous = false;
    r.interimResults = false;
    r.lang = 'en-US';
    recognitionSingleton = r;
    return r;
  }

  window.startVoiceInput = function(panelName) {
    if (isListening || window.__isPanelActive !== true) return;

    const recognition = getRecognition();

    recognition.onstart = () => {
      isListening = true;
      console.log(panelName + ' Voice input started...');
    };

    recognition.onend = () => {
      isListening = false;
      console.log(panelName + ' Voice input ended');
    };
    
    recognition.onresult = (event) => {
      let transcript = '';
      for (let i = event.resultIndex; i < event.results.length; i++) {
        transcript += event.results[i][0].transcript;
      }
      
      // Remove trailing period added by Web Speech API
      transcript = transcript.replace(/\.$/, '');
      
      const activeElement = document.activeElement;
      if (activeElement && (activeElement.tagName === 'INPUT' || activeElement.tagName === 'TEXTAREA')) {
        // Dispatch keydown event
        activeElement.dispatchEvent(new KeyboardEvent('keydown', { 
          bubbles: true, 
          cancelable: true,
          key: 'Unidentified'
        }));
        
        activeElement.value = transcript;
        
        // Dispatch input event
        activeElement.dispatchEvent(new Event('input', { bubbles: true }));
        
        // Dispatch keyup event
        activeElement.dispatchEvent(new KeyboardEvent('keyup', { 
          bubbles: true, 
          cancelable: true,
          key: 'Unidentified'
        }));
        
        // Dispatch change event
        activeElement.dispatchEvent(new Event('change', { bubbles: true }));
      } else {
        document.execCommand('insertText', false, transcript);
      }
      console.log('Voice input:', transcript);

      // Stop after a result to avoid lingering sessions
      try { recognition.stop(); } catch (_) {}
    };

    recognition.onerror = (event) => {
      isListening = false;
      console.error('Voice error:', event.error);
      try { recognition.stop(); } catch (_) {}
    };

    try {
      recognition.start();
    } catch (err) {
      // If already started, just log and skip
      console.warn('Voice start skipped:', err?.message || err);
    }
  };

  // Optional: keyboard shortcut (Ctrl+Shift+V for voice)
  document.addEventListener('keydown', (e) => {
    if (e.ctrlKey && e.shiftKey && e.code === 'KeyV') {
      e.preventDefault();
      window.startVoiceInput();
    }
  });
})();
