"use strict";
(function (window) {

var document = window.document;
var fetch = window.fetch;

function $(id) { return document.getElementById(id); }

function setOptionsToSelect(select, options) {
    var n = options.length,
        option, i;

    select.innerHTML = "";
    for (i = 0; i < n; i ++) {
        option = document.createElement("option");
        option.value = options[i];
        option.text = option.value;
        select.appendChild(option);
    }
}

function fetchJson() {
    var args = arguments;
    return new Promise(function (resolve, reject) {
        fetch.apply(null, args).then(function (res) {
            if (res.ok) {
                return res.json().then(function (content) {
                    resolve(content);
                });
            } else {
                return res.text().then(function (content) {
                    reject(content);
                });
            }
        }).catch(function (error) {
            reject("Network error occured: " + error.message);
        });
    });
}

function fetchHtml() {
    var args = arguments;
    return new Promise(function (resolve, reject) {
        fetch.apply(null, args).then(function (res) {
            if (res.ok) {
                return res.text().then(function (content) {
                    resolve(content);
                });
            } else {
                return res.text().then(function (content) {
                    reject(content);
                });
            }
        }).catch(function (error) {
            reject("Network error occured: " + error.message);
        });
    });
}

function postHtml(url, contents) {
    var formData = new FormData();
    Object.keys(contents).forEach(function (key) {
        formData.append(key, this[key]);
    }, contents);
    var postOption = {
            method: "POST",
            body: formData,
            credentials: "include",
            headers: {
                "X-Requested-With": "XMLHttpRequest"
            }
        };
    return fetchHtml(url, postOption);
}

var App = {
    branches: [],
    repoName: null,
    base: null,
    head: null,

    showError: function (message) {
        var divError = $("div-error"),
            el = document.createElement("div");

        this.hideLoading();

        el.innerHTML = message;
        divError.replaceChild(el, $("button-close-alert").nextSibling);

        divError.style.display = "block";
    },

    hideError: function () {
        $("div-error").style.display = "none";
    },

    showLoading: function () {
        $("div-loading").style.display = "block";
    },

    hideLoading: function () {
        $("div-loading").style.display = "none";
    },

    addEventListener: function (el, type, func) {
        var self = this;
        el.addEventListener(type, function () { return func.apply(self, arguments) }, false);
    },

    loadBranchesFromStorage: function () {
        var content;
        try {
            content = JSON.parse(window.localStorage.getItem("id:" + this.repoName));
            this.base = content["base"];
            this.head = content["head"];
            return true;
        } catch (e) {
            if (e instanceof SyntaxError) {
                return false;
            } else if (e instanceof TypeError) {
                return false;
            } else {
                alert(e);
                return false;
            }
        }
    },

    saveBranchesToStorage: function() {
        var content = { base: this.base, head: this.head };
        window.localStorage.setItem("id:" + this.repoName, JSON.stringify(content));
    },

    fetchBranchesAndSetToSelector: function () {
        var self = this;

        this.showLoading();

        $("button-generate-pr-body").disabled = true;

        fetchJson("/" + this.repoName + "/branches", { credentials: "include" }).then(function (branches) {
            var selectBaseBranches = $("select-base-branches"),
                selectHeadBranches = $("select-head-branches"),
                defaultBases = [
                    self.base, "master", "staging"
                ],
                defaultHeads = [
                    self.head, "develop", "staging"
                ],
                defaultBase = -1, defaultHead = -1,
                i;

            for (i = 0; i < defaultBases.length; i ++) {
                defaultBase = branches.indexOf(defaultBases[i]);
                if (defaultBase >= 0) break;
            }
            if (defaultBase < 0) {
                defaultBase = 0;
            }

            for (i = 0; i < defaultHeads.length; i ++) {
                defaultHead = branches.indexOf(defaultHeads[i]);
                if (defaultHead >= 0) break;
            }
            if (defaultHead < 0) {
                defaultHead = (defaultBase == 0) ? 1 : 0;
            }

            setOptionsToSelect(selectBaseBranches, branches);
            setOptionsToSelect(selectHeadBranches, branches);
            selectBaseBranches.selectedIndex = defaultBase;
            selectHeadBranches.selectedIndex = defaultHead;

            self.base = branches[defaultBase];
            self.head = branches[defaultHead];

            self.hideLoading();

            $("div-branch-selector").style.display = "block";
            $("div-generate-pr-body").style.display = "block";
            $("button-generate-pr-body").disabled = false;
        }, function (error) {
            self.showError(error);
        });
    },

    onSelectBaseBranchesChanged: function (ev) {
        this.base = ev.currentTarget.value;
    },

    onSelectHeadBranchesChanged: function (ev) {
        this.head = ev.currentTarget.value;
    },

    onButtonGeneratePrBodyClicked: function (ev) {
        var self = this,
            postData = {
                base: this.base,
                head: this.head
            };

        $("button-generate-pr-body").disabled = true;

        $("select-base-branches").disabled = true;
        $("select-head-branches").disabled = true;
        $("button-edit-branch").disabled = true;

        this.saveBranchesToStorage();

        this.showLoading();
        this.hideError();

        postHtml("/" + this.repoName + "/prepare", postData).then(function (contents) {
            $("div-form-pr-body").innerHTML = contents;

            self.hideLoading();

            $("text-base-branch").textContent = self.base;
            $("text-head-branch").textContent = self.head;
            $("button-edit-branch").style.display = "none";
            $("div-selected-branch").style.display = "block";
            $("div-branch-selector").style.display = "none";
            $("div-generate-pr-body").style.display = "none";

            $("div-form-pr-body").style.display = "block";
            $("div-form-pr-body").className = "visible";
        }, function (error) {
            self.showError(error);

            $("button-generate-pr-body").disabled = false;
            $("select-base-branches").disabled = false;
            $("select-head-branches").disabled = false;
            $("button-edit-branch").disabled = false;
        });
    },

    onButtonGeneratePrClicked: function (ev) {
        var self = this,
            postData = {
                base: this.base,
                head: this.head,
                title: $("text-title").value,
                body: $("text-body").value
            };

        $("button-generate-pr").disabled = true;

        $("text-title").disabled = true;
        $("text-body").disabled = true;

        this.showLoading();

        postHtml("/" + this.repoName + "/pr", postData).then(function (contents) {
            var div_pr_created = $("div-pr-created"),
                script, re, matched, el;

            re = /<script\s*(?:\s+[^>]+)?>([\s\S]*?)<\/script>/ig;
            matched = re.exec(contents);
            if (matched != null) {
                script = matched[1];
                contents = contents.substring(0, matched.index) + contents.substring(re.lastIndex);
            }

            div_pr_created.innerHTML = contents;
            if (script != null) {
                el = document.createElement("script");
                el.type = "text/javascript";
                el.text = script;
                div_pr_created.appendChild(el);
            }

            self.hideLoading();

            $("div-selected-branch").style.display = "block";
            $("div-form-pr-body").style.display = "none";
            div_pr_created.style.display = "block";
        }, function (error) {
            self.showError(error);
        });
    },

    onButtonEditBranchClicked: function (ev) {
        $("div-selected-branch").style.display = "none";
        this.fetchBranchesAndSetToSelector();
    },

    onReady: function (ev) {
        var self = this,
            handlers = {
                "button-edit-branch": this.onButtonEditBranchClicked,
                "button-generate-pr-body": this.onButtonGeneratePrBodyClicked,
                "button-generate-pr": this.onButtonGeneratePrClicked,
                "button-close-alert": this.hideError
            };

        this.repoName = document.body.getAttribute("data-repo-name");

        document.addEventListener("click", function (ev) {
            var handler;
            handler = handlers[ev.target.id];
            if (handler != null) {
                handler.apply(self, ev);
            }
        }, true);

        this.addEventListener($("select-base-branches"), "change", this.onSelectBaseBranchesChanged);
        this.addEventListener($("select-head-branches"), "change", this.onSelectHeadBranchesChanged);

        if (this.loadBranchesFromStorage()) {
            $("text-base-branch").textContent = this.base;
            $("text-head-branch").textContent = this.head;
            $("div-selected-branch").style.display = "block";
            $("div-generate-pr-body").style.display = "block";
        } else {
            this.fetchBranchesAndSetToSelector();
        }
     }
};

document.addEventListener('DOMContentLoaded', function () { return App.onReady.apply(App, arguments); }, false);

})(window);
