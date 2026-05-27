# CatechHub - GitHub Pages Setup

## Come attivare GitHub Pages per questo progetto

### Passo 1: Push del codice su GitHub
Assicurati che il codice sia pushato sul repository GitHub: `https://github.com/CatechHub-dev/CatechHub`

### Passo 2: Attiva GitHub Pages
1. Vai su GitHub
2. Apri il repository `CatechHub-dev/CatechHub`
3. Clicca su **Settings** (Impostazioni)
4. Nel menu laterale, clicca su **Pages**
5. In **Source**, seleziona:
   - **Branch**: `main`
   - **Folder**: `/docs`
6. Clicca su **Save**

### Passo 3: Attendi la pubblicazione
GitHub impiegherà qualche minuto per pubblicare il sito. Potrai vedere lo stato di deploy nella pagina Pages.

### Passo 4: Accedi al sito
Una volta completato il deploy, il sito sarà disponibile all'URL:
`https://catechhub-dev.github.io/CatechHub/`

## Struttura del sito

Il sito è composto da:
- `index.html` - Homepage con navigazione
- `styles.css` - Foglio di stile con design moderno
- `script.js` - JavaScript per interattività
- `_config.yml` - Configurazione Jekyll
- `.nojekyll` - Disabilita Jekyll processing

## Caratteristiche del design

### Design Giovanile e Moderno
- **Colori vivaci**: Gradiente viola/blu per hero section, accenti colorati
- **Tipografia moderna**: Font Poppins per un look fresco
- **Animazioni**: Effetti hover, scroll animations, transitions fluide
- **Layout responsive**: Perfetto su mobile, tablet e desktop

### Sezioni
1. **Hero**: Introduzione con call-to-action
2. **Features**: 9 funzionalità principali con icone
3. **Download**: Link per download e requisiti
4. **Info**: FAQ e informazioni aggiuntive

### Target Audience
- Catechisti parrocchiali
- Giovani adulti
- Volontari in ambito religioso

### Linguaggio
- Italiano contemporaneo e informale
- Terminologia comprensibile
- Tonico ma professionale

## Personalizzazione

### Modificare colori
In `styles.css`, modifica le variabili CSS in `:root`:
```css
:root {
    --primary: #174A7E;
    --secondary: #FF6B6B;
    --accent: #4ECDC4;
    /* ecc... */
}
```

### Modificare testo
In `index.html`, modifica il contenuto delle varie sezioni.

### Aggiungere nuove funzionalità
In `script.js`, puoi aggiungere nuove interattività JavaScript.

## Troubleshooting

### Il sito non si carica
- Controlla che la cartella `docs` sia nella root del repository
- Verifica che GitHub Pages sia attivo nelle impostazioni
- Controlla i log di deploy nella sezione Pages

### Lo stile non viene applicato
- Assicurati che il file `styles.css` sia nella cartella docs
- Verifica che il percorso nel file HTML sia corretto

### Le animazioni non funzionano
- Controlla che `script.js` sia caricato correttamente
- Verifica la console del browser per errori JavaScript

## Aggiornamenti

Per aggiornare il sito:
1. Modifica i file nella cartella `docs`
2. Fai commit e push delle modifiche
3. GitHub pubblicherà automaticamente le modifiche

## Supporto

Per problemi o suggerimenti:
- Apri una issue su GitHub: `https://github.com/CatechHub-dev/CatechHub/issues`
- Contatta il team di sviluppo
