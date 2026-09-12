// Runs inside the shared Safari page. Whatever `completionFunction` receives is handed to
// the extension under NSExtensionJavaScriptPreprocessingResultsKey.
var SharePreprocessor = function () {};

SharePreprocessor.prototype = {
    run: function (args) {
        args.completionFunction({
            url: document.URL,
            title: this.pageTitle(),
            description: this.metaContent(['og:description', 'twitter:description', 'description']),
            price: this.price(),
            selection: window.getSelection ? String(window.getSelection()) : ''
        });
    },

    finalize: function (args) {},

    pageTitle: function () {
        return this.metaContent(['og:title', 'twitter:title']) || document.title || '';
    },

    price: function () {
        var meta = this.metaContent(['product:price:amount', 'og:price:amount', 'twitter:data1']);
        if (meta) { return meta; }
        var node = document.querySelector('[itemprop="price"]');
        if (node) {
            return node.getAttribute('content') || (node.textContent || '').trim();
        }
        return '';
    },

    metaContent: function (names) {
        for (var i = 0; i < names.length; i++) {
            var name = names[i];
            var node = document.querySelector('meta[property="' + name + '"], meta[name="' + name + '"]');
            if (node) {
                var content = (node.getAttribute('content') || '').trim();
                if (content) { return content; }
            }
        }
        return '';
    }
};

var ExtensionPreprocessingJS = new SharePreprocessor();
