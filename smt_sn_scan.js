smt_sn_scan_in_db = sessionStorage.getItem("DB_NAME");
smt_sn_scan_in_sp = "MES1.SMT_SN_SCAN";

$(function(){

    //#region ---------------- BEGIN: CONFIG LINE ----------------
    smt_sn_scan_get_line_station();

    smt_sn_scan_get_cmb_line();

    $('#smt_sn_scan_line').change(function(event){
        let line_name = $('#smt_sn_scan_line').val();
        smt_sn_scan_get_cmb_station(line_name);
    });

    $('#smt_sn_scan_btn_confirm').click(function () {
        let line_name = $('#smt_sn_scan_line').val();
        let station = $('#smt_sn_scan_station').val();
        
        if (line_name === '' || station === '') {
            smt_sn_scan_show_message("ERROR", "PLEASE ENTER FULL DATA.", "#EF5350", "error");
        }
        else {
            smt_sn_scan_get_config_line(line_name + ';' + station);
            $('#smt_sn_scan_txt_line').text(line_name);
            $('#smt_sn_scan_txt_station').text(station);
        }
    });
    //#endregion ---------------- END: CONFIG LINE ----------------


    //#region ---------------- BEGIN: MATERIAL SCAN ----------------
    $("#smt_sn_scan_wo").focus();
    $('#smt_sn_scan_wo').keypress(function(event){
        if (event.which === 13){
            event.preventDefault();
            let wo = $("#smt_sn_scan_wo").val().trim();
            let station_name = $("#smt_sn_scan_txt_station").text();
            
            if (wo === '' || station_name === '') {
                $('#smt_sn_scan_message').text("WO OR STATION_NAME IS EMPTY. PLEASE CHECK!").css("color", "red");
            }
            else {
                smt_sn_scan_get_wo_data(wo, station_name);
            }
        }
    });

    let interval_id = setInterval(() => {
        let element = document.getElementById('menu-smt_sn_scan');
        if (element === null) {
            clearInterval(interval_id);
        } else if (element.classList.contains('active')) {
            let wo = $("#smt_sn_scan_wo").val().trim();
            let station_name = $("#smt_sn_scan_txt_station").text();

            if (wo != '' && station_name != '') {
                smt_sn_scan_get_wo_data(wo, station_name);
            }
        }
    }, 10 * 1000);

    $('#smt_sn_scan_data_scan').keypress(function(event){
        if (event.which === 13){
            event.preventDefault();
            let data_scan = $("#smt_sn_scan_data_scan").val().trim();
            let station_name = $("#smt_sn_scan_txt_station").text();
            $("#smt_sn_scan_data_scan").focus();
            $("#smt_sn_scan_data_scan").select();

            if (data_scan === '' || station_name === '') {
                $('#smt_sn_scan_message').text("DATA_SCAN OR STATION_NAME IS EMPTY. PLEASE CHECK!").css("color", "red");
            } else {
                smt_sn_scan_material_scan(data_scan, station_name);
            }
        }
    });
    //#endregion ---------------- END: MATERIAL SCAN ----------------


    //#region ---------------- BEGIN: SN SCAN ----------------
    $('#smt_sn_scan_sn').keypress(function(event){
        if (event.which === 13){
            event.preventDefault();
            let sn = $("#smt_sn_scan_sn").val().trim();
            let station_name = $("#smt_sn_scan_txt_station").text();
            let emp_no = sessionStorage.getItem("EMP_NO").trim();

            $("#smt_sn_scan_sn").focus();
            $("#smt_sn_scan_sn").select();

            if (sn === '' || station_name === '') {
                $('#smt_sn_scan_message').text("SN OR STATION_NAME IS EMPTY. PLEASE CHECK!").css("color", "red");
            }
            else {
                smt_sn_scan_sn_scan(sn, station_name, emp_no);
            }
        }
    });
    //#endregion ---------------- END: SN SCAN ----------------
});

//#region ---------------- BEGIN: GENERAL FUNCTION ----------------
function smt_sn_scan_show_message(title, text, color, type) {
    swal({
        title: title,
        text: text,
        confirmButtonColor: color,
        type: type
    });
}

function smt_sn_scan_show_datagrid(dt, id_table) {
    let thead = '<thead><tr class="bg-primary">';
    $.each(dt[0], function (i, dt_thead) {
        thead += '<th>' + i.toUpperCase() + '</th>';
    });
    thead += '</tr></thead>';

    /*-----Begin Add tbody-----*/
    let tbody = '<tbody>';
    $.each(dt, function (i, dt_tbody) {
        let rowClass = '';

        // Lấy giá trị EXT_QTY và STANDARD_QTY từ dòng hiện tại
        let ext_qty = parseFloat(dt_tbody['EXT_QTY']);
        let standard_qty = parseFloat(dt_tbody['STANDARD_QTY']);

        // Kiểm tra điều kiện: EXT_QTY == 0 hoặc (EXT_QTY > 0 && EXT_QTY < STANDARD_QTY * 20)
        if (
            (!isNaN(ext_qty) && ext_qty === 0) ||
            (!isNaN(ext_qty) && !isNaN(standard_qty) && ext_qty > 0 && ext_qty < standard_qty * 20)
        ) {
            rowClass = ' style="background-color: red; color: white;"';
        }

        tbody += '<tr' + rowClass + '>';
        $.each(dt_tbody, function (key, val_data) {
            tbody += '<td>' + val_data + '</td>';
        });
        tbody += '</tr>';
    });
    tbody += '</tbody>';
    /*-----End Add tbody-----*/

    $(id_table).html(thead + tbody);
}
//#endregion ---------------- END: GENERAL FUNCTION ----------------

//#region ---------------- BEGIN: CONFIG LINE ----------------
function smt_sn_scan_get_line_station() {
    data_input = {
        'IN_DB': smt_sn_scan_in_db,
        'IN_SP': smt_sn_scan_in_sp,
        'IN_EVENT': 'GET_LINE_STATION',
        'IN_DATA': '{"IP_CLIENT": "' + sessionStorage.getItem("IP_CLIENT").trim() + '"}'
    }
    call_api(data_input)
        .then(response => {
            if (response.Message.substring(0, 2).toUpperCase() == 'OK' && response.Code == '1') {
                var dt = RemoveNull(response.Data);
                if (dt.length > 0) {
                    let line_name = dt[0].LINE_STATION.split(';')[0];
                    let station_name = dt[0].LINE_STATION.split(';')[1];
                    $('#smt_sn_scan_txt_line').text(line_name);
                    $('#smt_sn_scan_txt_station').text(station_name);
                }
            } else {
                smt_sn_scan_show_message("ERROR", response.Message, "#EF5350", "error")
            }
        })
        .catch(error => {
            smt_sn_scan_show_message("CALL API FAIL", error, "#EF5350", "error")
        });
}

function smt_sn_scan_get_cmb_line() {
    data_input = {
        'IN_DB': smt_sn_scan_in_db,
        'IN_SP': smt_sn_scan_in_sp,
        'IN_EVENT': 'GET_CMB_LINE',
        'IN_DATA': '{}'
    }
    call_api(data_input)
        .then(response => {
            if (response.Message.substring(0, 2).toUpperCase() == 'OK' && response.Code == '1') {
                var dt = RemoveNull(response.Data);
                if (dt.length > 0) {
                    $('#smt_sn_scan_line option').remove();
                    $('#smt_sn_scan_line').append('<option value="">Choose LINE</option>');
                    dt.forEach(element => {
                        let line_name = element.LINE_NAME + element.LINE_SECTION;
                        $('#smt_sn_scan_line').append('<option value="'+line_name+'">'+line_name+'</option>');
                    });
                }
                else {
                    $('#smt_sn_scan_line option').remove();
                    $('#smt_sn_scan_line').append('<option value="">NO DATA</option>');
                }
            } else {
                smt_sn_scan_show_message("ERROR", response.Message, "#EF5350", "error")
            }
        })
        .catch(error => {
            smt_sn_scan_show_message("CALL API FAIL", error, "#EF5350", "error")
        });
}

function smt_sn_scan_get_cmb_station(line_name) {
    data_input = {
        'IN_DB': smt_sn_scan_in_db,
        'IN_SP': smt_sn_scan_in_sp,
        'IN_EVENT': 'GET_CMB_STATION',
        'IN_DATA': '{"LINE_NAME": "' + line_name + '"}'
    }
    call_api(data_input)
        .then(response => {
            if (response.Message.substring(0, 2).toUpperCase() == 'OK' && response.Code == '1') {
                var dt = RemoveNull(response.Data);
                if (dt.length > 0) {
                    $('#smt_sn_scan_station option').remove();
                    $('#smt_sn_scan_station').append('<option value="">Choose STATION</option>');
                    dt.forEach(element => {
                        $('#smt_sn_scan_station').append('<option value="'+element.STATION_NAME+'">'+element.STATION_NAME+'</option>');
                    });
                }
                else {
                    $('#smt_sn_scan_station option').remove();
                    $('#smt_sn_scan_station').append('<option value="">NO DATA</option>');
                }
            } else {
                smt_sn_scan_show_message("ERROR", response.Message, "#EF5350", "error")
            }
        })
        .catch(error => {
            smt_sn_scan_show_message("CALL API FAIL", error, "#EF5350", "error")
        });
}

function smt_sn_scan_get_config_line(line_station) {
    data_input = {
        'IN_DB': smt_sn_scan_in_db,
        'IN_SP': smt_sn_scan_in_sp,
        'IN_EVENT': 'CONFIG_LINE',
        'IN_DATA': '{"LINE_STATION": "' + line_station 
        + '", "LOGIN_EMP": "' + sessionStorage.getItem("EMP_NO").trim()
        + '", "IP_CLIENT": "' + sessionStorage.getItem("IP_CLIENT").trim()
        + '"}'
    }
    call_api(data_input)
        .then(response => {
            if (response.Message.substring(0, 2).toUpperCase() == 'OK' && response.Code == '1') {
                var dt = RemoveNull(response.Data);
                if (dt.length > 0) {
                    smt_sn_scan_show_message("SUCCESS", "CONFIG LINE SUCCESSFULLY.", "green", "success");
                }
            } else {
                smt_sn_scan_show_message("ERROR", response.Message, "#EF5350", "error")
            }
        })
        .catch(error => {
            smt_sn_scan_show_message("CALL API FAIL", error, "#EF5350", "error")
        });
}
//#endregion ---------------- END: CONFIG LINE ----------------


//#region ---------------- BEGIN: MATERIAL SCAN ----------------
function smt_sn_scan_material_scan(data_scan, station_name) {
    data_input = {
        'IN_DB': smt_sn_scan_in_db,
        'IN_SP': smt_sn_scan_in_sp,
        'IN_EVENT': 'MATERIAL_SCAN',
        'IN_DATA': '{"DATA_SCAN": "' + data_scan.toUpperCase()
        + '", "STATION_NAME": "' + station_name
        + '"}'
    }
    call_api(data_input)
        .then(response => {
            if (response.Message.substring(0, 2).toUpperCase() == 'OK' && response.Code == '1') {
                var dt = RemoveNull(response.Data);
                if (dt.length > 0) {
                    $('#smt_sn_scan_message').text(response.Message).css("color", "green");
                }
            } else {
                $('#smt_sn_scan_message').text(response.Message).css("color", "red");
            }
        })
        .catch(error => {
            $('#smt_sn_scan_message').text(error).css("color", "red");
        });
}

function smt_sn_scan_get_wo_data(wo, station_name) {
    data_input = {
        'IN_DB': smt_sn_scan_in_db,
        'IN_SP': smt_sn_scan_in_sp,
        'IN_EVENT': 'GET_WO_DATA_NO_LOG',
        'IN_DATA': '{"WO": "' + wo
        + '", "STATION_NAME": "' + station_name
        + '"}'
    }
    call_api(data_input)
        .then(response => {
            let dt = RemoveNull(response.Data);
            if (response.Message.substring(0, 2).toUpperCase() == 'OK' && response.Code == '1') {
                if (dt.length > 0) {
                    $('#smt_sn_scan_input_qty').val(dt[0].INPUT_QTY);
                    $('#smt_sn_scan_input_target_qty').val(dt[0].TARGET_QTY);
                    $('#smt_sn_scan_data_table_material').html('');
                    smt_sn_scan_show_datagrid(dt, '#smt_sn_scan_data_table_material');
                }
            }
            else {
                if (dt.length > 0) {
                    $('#smt_sn_scan_input_qty').val(dt[0].INPUT_QTY);
                    $('#smt_sn_scan_input_target_qty').val(dt[0].TARGET_QTY);
                    $('#smt_sn_scan_data_table_material').html('');
                    smt_sn_scan_show_datagrid(dt, '#smt_sn_scan_data_table_material');
                }
                $('#smt_sn_scan_message').text(response.Message).css("color", "red");
            }
        })
        .catch(error => {
            $('#smt_sn_scan_message').text(error).css("color", "red");
        });
}
//#endregion ---------------- END: MATERIAL SCAN ----------------


//#region ---------------- BEGIN: SN SCAN ----------------
function smt_sn_scan_sn_scan(sn, station_name, emp_no) {
    data_input = {
        'IN_DB': smt_sn_scan_in_db,
        'IN_SP': smt_sn_scan_in_sp,
        'IN_EVENT': 'SN_SCAN',
        'IN_DATA': '{"SN": "' + sn.toUpperCase()
        + '", "STATION_NAME": "' + station_name
        + '", "EMP_NO": "' + emp_no
        + '"}'
    }
    call_api(data_input)
        .then(response => {
            let dt = RemoveNull(response.Data);
            if (response.Message.substring(0, 2).toUpperCase() == 'OK' && response.Code == '1') {
                if (dt.length > 0) {
                    $('#smt_sn_scan_wo').val(dt[0].WO);
                    $('#smt_sn_scan_input_qty').val(dt[0].INPUT_QTY);
                    $('#smt_sn_scan_input_target_qty').val(dt[0].TARGET_QTY);
                    $('#smt_sn_scan_message').text(response.Message).css("color", "green");
                    $('#smt_sn_scan_data_table_material').html('');
                    smt_sn_scan_show_datagrid(dt, '#smt_sn_scan_data_table_material');
                }
            }
            else {
                if (dt.length > 0) {
                    $('#smt_sn_scan_wo').val(dt[0].WO);
                    $('#smt_sn_scan_input_qty').val(dt[0].INPUT_QTY);
                    $('#smt_sn_scan_input_target_qty').val(dt[0].TARGET_QTY);
                    $('#smt_sn_scan_data_table_material').html('');
                    smt_sn_scan_show_datagrid(dt, '#smt_sn_scan_data_table_material');
                }
                $('#smt_sn_scan_message').text(response.Message).css("color", "red");
            }
        })
        .catch(error => {
            $('#smt_sn_scan_message').text(error).css("color", "red");
        });
}
//#endregion ---------------- END: SN SCAN ----------------