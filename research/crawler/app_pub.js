function dgpageInit(id) {
    var p = $('#' + id).datagrid('getPager');
    $(p).pagination({
        beforePageText: '第',
        afterPageText: '页    共 {pages} 页',
        displayMsg: '当前显示 {from} - {to} 条记录   共 {total} 条记录',
        onBeforeRefresh: function () {
            $(this).pagination('loading');

            $(this).pagination('loaded');
        }
    });
}

function mergeCells(dg, data, cellnames) {
    for (var i = 0; i < cellnames.length; i++) {
        var cellname = cellnames[i];
        var merges = [];
        for (var r = 0; r < data.rows.length; r++) {
            var row = data.rows[r];
            var mergeinfo = new Object();
            var nr = row[cellname];
            var rowspan = 1;
            for (var r1 = r + 1; r1 < data.rows.length; r1++) {
                var row1 = data.rows[r1];
                var nr1 = row1[cellname];

                if (nr1 && nr1 == nr && nr1 != "") {
                    mergeinfo.index = r;
                    rowspan++;
                    mergeinfo.rowspan = rowspan;
                }
                else {
                    if (rowspan > 1) {
                        merges.push(mergeinfo);
                        r = r1 - 1;
                    }
                    break;
                }
                if (r1 == data.rows.length - 1) {
                    if (rowspan > 1) {
                        merges.push(mergeinfo);
                        r = r1 - 1;
                    }
                }
            }
        }
        for (var j = 0; j < merges.length; j++) {
            $('#' + dg).datagrid('mergeCells', {
                index: merges[j].index,
                field: cellname,
                rowspan: merges[j].rowspan
            });
        }
    }
}

function mergeCells_table(dg, data, cellnames) {
    var table = document.getElementById(dg);
    for (var i = 0; i < cellnames.length; i++) {
        var cellname = cellnames[i];
        var merges = [];
        for (var r = 0; r < data.rows.length; r++) {
            var row = data.rows[r];
            var mergeinfo = new Object();
            var nr = row[cellname];
            var rowspan = 1;
            for (var r1 = r + 1; r1 < data.rows.length; r1++) {
                var row1 = data.rows[r1];
                var nr1 = row1[cellname];

                if (nr1 && nr1 == nr && nr1 != "") {
                    mergeinfo.index = r;
                    rowspan++;
                    mergeinfo.rowspan = rowspan;
                    table.rows[r + 1].cells[i].rowSpan = rowspan;
                    table.rows[r1 + 1].cells[i].style.display = "none";
                }
                else {
                    if (rowspan > 1) {
                        merges.push(mergeinfo);
                        r = r1 - 1;
                    }
                    break;
                }
                if (r1 == data.rows.length - 1) {
                    if (rowspan > 1) {
                        merges.push(mergeinfo);
                        r = r1 - 1;
                    }
                }
            }
        }
    }
}

function mergeCells_table1(dg, data, cellnames,cellindexs) {
    var table = document.getElementById(dg);
    for (var i = 0; i < cellnames.length; i++) {
        var cellname = cellnames[i];
        var merges = [];
        for (var r = 0; r < data.rows.length; r++) {
            var row = data.rows[r];
            var mergeinfo = new Object();
            var nr = row[cellname];
            var rowspan = 1;
            for (var r1 = r + 1; r1 < data.rows.length; r1++) {
                var row1 = data.rows[r1];
                var nr1 = row1[cellname];

                if (nr1 && nr1 == nr && nr1 != "") {
                    mergeinfo.index = r;
                    rowspan++;
                    var cellindex = cellindexs[i];
                    mergeinfo.rowspan = rowspan;
                    table.rows[r + 1].cells[cellindex].rowSpan = rowspan;
                    table.rows[r1 + 1].cells[cellindex].style.display = "none";
                }
                else {
                    if (rowspan > 1) {
                        merges.push(mergeinfo);
                        r = r1 - 1;
                    }
                    break;
                }
                if (r1 == data.rows.length - 1) {
                    if (rowspan > 1) {
                        merges.push(mergeinfo);
                        r = r1 - 1;
                    }
                }
            }
        }
    }
}

//cellcomp列相同，cellnames合并
function mergeCells_one(dg, data, cellcomp, cellnames) {
    var merges = [];
    for (var r = 0; r < data.rows.length; r++) {
        var row = data.rows[r];
        var mergeinfo = new Object();
        var nr = row[cellcomp];
        var rowspan = 1;
        for (var r1 = r + 1; r1 < data.rows.length; r1++) {
            var row1 = data.rows[r1];
            var nr1 = row1[cellcomp];

            if (nr1 && nr1 == nr && nr1 != "") {
                mergeinfo.index = r;
                rowspan++;
                mergeinfo.rowspan = rowspan;
            }
            else {
                if (rowspan > 1) {
                    merges.push(mergeinfo);
                    r = r1 - 1;
                }
                break;
            }
            if (r1 == data.rows.length - 1) {
                if (rowspan > 1) {
                    merges.push(mergeinfo);
                    r = r1 - 1;
                }
            }
        }
    }
    for (var i = 0; i < cellnames.length; i++) {
        var cellname = cellnames[i];
        for (var j = 0; j < merges.length; j++) {
            $('#' + dg).datagrid('mergeCells', {
                index: merges[j].index,
                field: cellname,
                rowspan: merges[j].rowspan
            });
        }
    }
}

$.fn.serializeObject = function () {
    var o = {};
    var a = this.serializeArray();
    $.each(a, function () {
        if (o[this.name]) {
            if (!o[this.name].push) {
                o[this.name] = [o[this.name]];
            }
            o[this.name].push(this.value || '');
        } else {
            o[this.name] = this.value || '';
        }
    });
    return o;
};  


/**
* 设置未来(全局)的AJAX请求默认选项
* 主要设置了AJAX请求遇到Session过期的情况
*/
$.ajaxSetup({
    contentType: "application/x-www-form-urlencoded;charset=utf-8",
    complete: function (XMLHttpRequest, textStatus) {
        //通过XMLHttpRequest取得响应头，sessionstatus，
        var sessionstatus = XMLHttpRequest.getResponseHeader("sessionstatus");
        var loginurl = XMLHttpRequest.getResponseHeader("loginurl");
        if (sessionstatus == "timeout") {
//            alert("由于您长时间没有操作, session已过期, 请重新登录.");
            var top = getTopWinow();
            top.location.href = loginurl;
        }
    }
});
 
/**
* 在页面中任何嵌套层次的窗口中获取顶层窗口
* @return 当前页面的顶层窗口对象
*/
function getTopWinow() {
    var p = window;
    while (p != p.parent) {
        p = p.parent;
    }
    return p;
}

function isNumber(str) {
    var reg = /^[0-9]*[1-9][0-9]*$/;
    return reg.test(str);
}

function isEmail(str) {
    var reg = /^([a-zA-Z0-9_-])+@([a-zA-Z0-9_-])+((\.[a-zA-Z0-9_-]{2,3}){1,2})$/;
    return reg.test(str);
}

//护照
function isPassport(str) {
    var reg = /^[a-zA-Z0-9]{3,21}$/;
    return reg.test(str);
}
//港澳回归证和台胞证
function isZjGat(str) {
    var reg = /^[a-zA-Z0-9]{5,21}$/;
    return reg.test(str);
}
//外国人居留许可证
function isPermit(str) {
    var reg = /^[a-zA-Z]{3}\d{12}$/;
    return reg.test(str);
}

//全选与反选共用 
function check_all(inputcheck, strid) {
    var inputs = document.getElementsByTagName("input");
    for (var i = 0; i < inputs.length; i++) {
        if (inputs[i].type == "checkbox") {
            if (inputs[i].id.indexOf(strid) != -1)
                inputs[i].checked = document.getElementById(inputcheck).checked;
        }
    }
}

function txtNumKeyPress(txt) {
    var code = (event.keyCode ? event.keyCode : event.which);
    if (typeof ($.browser) != "undefined" && !$.browser.msie && (event.keyCode == 0x8))   // if firefox
    {
        return;
    }
    
    event.returnValue = code >= 48 && code <= 57 || event.keyCode == 46;  // number or dot 
}

function txtNumblur(txt) {
    if (isNaN(txt.value)) {
        txt.value = "";
    }
    if (txt.value.lastIndexOf(".") == (txt.value.length - 1)) {
        txt.value = txt.value.substr(0, txt.value.length - 1);
    }
    if (txt.value.indexOf(".") > 0) {
        txt.value = txt.value.substr(0, txt.value.indexOf(".") + 2);
    }
    if (parseFloat(txt.value) > 100) {
        txt.value = "100";
    }
}


//文本框禁止粘贴操作 onkeydown="fncKeyStop(event)" onpaste="return false"
function fncKeyStop(evt) {
    if (!window.event) {
        var keyhh = window.event ? event.keyCode : event.which;
        var keycode = keyhh;
        var key = String.fromCharCode(keycode).toLowerCase();
        if (evt.ctrlKey && key == "v") {
            evt.preventDefault();
            evt.stopPropagation();
        }
    }
}


//Javascript正则控制文本框只能输入整数或浮点数onkeyup="CheckInputIntFloat(this)" 
function CheckInputIntFloat(oInput) {
    if ('' != oInput.value.replace(/\d{1,}\.{0,1}\d{0,}/, '')) {
        oInput.value = oInput.value.match(/\d{1,}\.{0,1}\d{0,}/) == null ? '' : oInput.value.match(/\d{1,}\.{0,1}\d{0,}/);
    }
    if ("" != oInput.value) {
        if (oInput.value.indexOf('.') <= -1) {
            if (oInput.value.length > 3) {
                oInput.value = '';
            }
        } else {
            var strs = new Array(); //定义一数组 
            strs = oInput.value.split('.'); //字符分割
            if (strs[0].toString().length > 2) {
                oInput.value = '';
            }
            if (oInput.value.length > 5) {
                oInput.value = '';
            }

        }
    }
}

/** 
* 扩展combox验证，easyui原始只验证select text的值，不支持value验证 
*/
$.extend($.fn.validatebox.defaults.rules, {
    comboxValidate: {
        validator: function (value, param, missingMessage) {
            try {
                if ($('#' + param).combobox('getValue') != '' && $('#' + param).combobox('getValue') != null) {
                    return true;
                }
                return false;
            }
            catch (ex) {
                //$('#' + param).val("");
                return false;
            }
        },
        message: "{1}"
    }
});


function responseTextTitle(responseText)
{
    var index1 = responseText.indexOf("<title>");
    var index11 = responseText.indexOf("<TITLE>");
    index1 = index1 > index11 ? index1 : index11;
    var index2 = responseText.indexOf("</title>");
    var index22 = responseText.indexOf("</TITLE>");
    index2 = index2 > index22 ? index2 : index22;
    if (index1 > 0 && index2>0) {
        return responseText.substring(index1 + 7, index2);
    }
    else {
        return responseText;
    }
}

//aes加密
String.prototype.AESEncrypt = function () {
    var key = CryptoJS.enc.Utf8.parse("8NONwyJtHesysWpM"); //8NONwyJtHesysWpM
    var realcontent = this.toString();
    var encontent = CryptoJS.AES.encrypt(realcontent, key, {
        mode: CryptoJS.mode.ECB,
        padding: CryptoJS.pad.Pkcs7
    });
    var encryptedData = encontent.ciphertext.toString()
    return encryptedData;
}

String.prototype.trim = function () {
    var restr = this.replace(/(^[\s\n\t]+|[\s\n\t]+$)/g, "");
    return restr;
}

String.prototype.getParamvalueBykey = function (key) {
    var reg = new RegExp("" + key + "=([^&]*)")
    var urlstr = this.toString();
    var mathresult = reg.exec(this.toString());
    if (mathresult != null)
        return mathresult[1];
    else
        return "";
}

//url:下载地址
//option:json参数选项，键值data:请求参数，为json对象，键值loadtext:等待信息提示,键值noPageload:是否不弹出等待层
$.fileSubmit = function (url, option) {
    var loadtext = "请稍等。。。";
    if (option.loadtext)
        loadtext = option.loadtext;
    var data = {};
    if (option.data)
        data = option.data;
    if (!option.noPageload)
        pageloadms(loadtext);
    fetch(url, {
        method: "post",
        body: JSON.stringify(data),
        'headers': {
            "accept": "*/*",
            "sec-fetch-dest": "empty",
            "sec-fetch-mode": "cors",
            "sec-fetch-site": "none",
            'content-type': 'application/json'  // 内容类型
        }
    }).then(response => {
        if (!response.ok) {
            throw new Error('Network response was not ok ' + response.statusText);
        }
        //const fileNameEncode = response.headers
        //    .get('Content-Disposition')
        //    .split('filename*=')[1]
        //fileName = decodeURIComponent(fileNameEncode);
        //fileName = fileName.replace("UTF-8''", "");

        fileName = ''; // 默认文件名兜底

        const disposition = response.headers.get('Content-Disposition');

        if (disposition) {
            // 优先取 filename*=（RFC 5987，带编码声明）
            const utf8Match = disposition.match(/filename\*=UTF-8''(.+)/i);
            // 其次取普通 filename=（URL编码或普通字符串）
            const normalMatch = disposition.match(/filename=([^;]+)/i);

            if (utf8Match) {
                fileName = decodeURIComponent(utf8Match[1].trim());
            } else if (normalMatch) {
                fileName = decodeURIComponent(normalMatch[1].trim().replace(/['"]/g, ''));
            }
        }

        return response.blob(); // 将响应转换为Blob对象
    })
        .then(blob => {
            // 创建一个Blob URL
            const blobUrl = URL.createObjectURL(blob);

            // 这里你可以使用blobUrl做你想做的事，比如下载文件等
            // 例如，创建一个链接来下载
            const downloadLink = document.createElement('a');
            downloadLink.href = blobUrl;
            downloadLink.download = fileName;
            document.body.appendChild(downloadLink);
            downloadLink.click();
            dispageload();
            // 清除Blob URL
            URL.revokeObjectURL(blobUrl);
        })
        .catch(error => {
            dispageload();
            console.error('There has been a problem with your fetch operation:', error);
        });
};