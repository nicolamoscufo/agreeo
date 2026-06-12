VS Code non espone un'impostazione diretta per cambiare il font dell'interfaccia (menu, pannelli, UI generale).

Opzioni per applicare `System Sans` come UI font:

1. Usa l'estensione "Custom CSS and JS Loader" (o simile) che permette di caricare un file CSS personalizzato.
2. Crea un file CSS, ad es. `.vscode/custom-ui-font.css`, con il contenuto:

   ```css
   * {
     font-family: 'System Sans', system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial !important;
   }
   ```

3. Imposta nelle `settings.json` utente la chiave richiesta dall'estensione (es. `vscode_custom_css.imports`) con il percorso `file:///C:/.../agreeo/.vscode/custom-ui-font.css`.
4. Segui le istruzioni dell'estensione per abilitare il CSS personalizzato e riavvia VS Code.

Nota: l'uso di CSS personalizzato richiede di fidarsi dell'estensione e può interferire con aggiornamenti di VS Code. Se vuoi, posso creare il file CSS e le istruzioni passo-passo per la tua installazione.
