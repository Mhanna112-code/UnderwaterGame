// Read only this named browser session's owned game origin; no fixture seed.
async (page) => {
  return await page.evaluate(async () => {
    const result = [];
    for (const info of await indexedDB.databases()) {
      const db = await new Promise((resolve, reject) => {
        const request = indexedDB.open(info.name);
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      if (db.objectStoreNames.contains('FILE_DATA')) {
        const store = db.transaction('FILE_DATA', 'readonly').objectStore('FILE_DATA');
        const keys = await new Promise(resolve => {
          const request = store.getAllKeys();
          request.onsuccess = () => resolve(request.result);
        });
        for (const key of keys.filter(key => String(key).endsWith('.json'))) {
          const record = await new Promise(resolve => {
            const request = store.get(key);
            request.onsuccess = () => resolve(request.result);
          });
          try {
            const data = JSON.parse(new TextDecoder().decode(record.contents));
            result.push({database: info.name, key, route: data.route_state,
              inventory: data.inventory, party: data.divers,
              saveSequence: data.save_sequence});
          } catch (_) { /* Other non-save JSON is not a checkpoint witness. */ }
        }
      }
      db.close();
    }
    return result;
  });
}
