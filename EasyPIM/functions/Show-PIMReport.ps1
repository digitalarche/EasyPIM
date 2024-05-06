﻿<#
    .Synopsis
    Visualize PIM activities
      
    .Description
    Visualire PIM activities
    
    .Example
    PS> Get-PIMReport -tennantID $tenantID

    

    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
    
#>
function Show-PIMReport {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [System.String]
        # Tenant ID
        $tenantID
    )
    try {
        $Script:tenantID = $tenantID

        $allresults = @()

        $top = 100
        $endpoint = "auditlogs/directoryAudits?`$filter=loggedByService eq 'PIM'&`$top=$top"
        $result = invoke-graph -Endpoint $endpoint -Method "GET"
        
        $allresults += $result.value

        if ($result."@odata.nextLink") {
            do {
                $endpoint = $result."@odata.nextLink" -replace "https://graph.microsoft.com/v1.0/", ""
                $result = invoke-graph -Endpoint $endpoint -Method "GET"
                $allresults += $result.value
            }
            until(
                !($result."@odata.nextLink")
            )
        }

        #filter activities from the PIM service and completed activities
        $allresults = $allresults | Where-Object { $null -ne $_.initiatedby.values.userprincipalname } | Where-Object { $_.activityDisplayName -notmatch "completed" }
        $Myoutput = @()

        $allresults | ForEach-Object {
            $props = @{}
            $props["activityDateTime"] = $_.activityDateTime
            $props["activityDisplayName"] = $_.activityDisplayName
            $props["category"] = $_.category
            $props["operationType"] = $_.operationType
            $props["result"] = $_.result
            $props["resultReason"] = $_.resultReason
            $props["initiatedBy"] = $_.initiatedBy.values.userprincipalname
            $props["role"] = $_.targetResources[0]["displayname"]
            if ( ($_.targetResources | Measure-Object).count -gt 2) {
                if ($_.targetResources[2]["type"] -eq "User") {
                    $props["targetUser"] = $_.targetResources[2]["userprincipalname"]
                }
                elseif ($_.targetResources[2]["type"] -eq "Group") {
                    $props["targetGroup"] = $_.targetResources[2]["displayname"]
                }


                $props["targetResources"] = $_.targetResources[3]["displayname"]


            }
            else { $props["targetResources"] = $_.targetResources[0].displayname }
            $Myoutput += New-Object PSObject -Property $props
        }
        $Myoutput

        #Data for the HTML report

        $props = @{}
        $stats_category = @{}
        $categories = $Myoutput | Group-Object -Property category
        $categories | ForEach-Object {
            $stats_category[$_.Name] = $_.Count
        }
        $props["category"] = $stats_category
    
        $stats_requestor = @{}
        $requestors = $Myoutput | Group-Object -Property initiatedBy | Sort-Object -Property Count -Descending -top 10
        $requestors | ForEach-Object {
            $stats_requestor[$_.Name] = $_.Count
        }
        $props["requestor"] = $stats_requestor
    
        $stats_result = @{}
        $results = $Myoutput | Group-Object -Property result
        $results | ForEach-Object {
            $stats_result[$_.Name] = $_.Count
        }
        $props["result"] = $stats_result
    
        $stats_activity = @{}
        $activities = $Myoutput | Group-Object -Property activityDisplayName
        $activities | ForEach-Object {
            if ($_.Name -notmatch "completed") {
                $stats_activity[$_.Name] = $_.Count
            }
                
        }
        $props["activity"] = $stats_activity

        $stats_group=@{}
        $targetgroup= $Myoutput | Where-Object {$_.category -match "group"}|Group-Object -Property targetresources |Sort-Object -Property Count -Descending -top 10
        $targetgroup | ForEach-Object {
            $stats_group[$_.Name] = $_.Count
        }
        $props["targetgroup"] = $stats_group

        $stats_resource=@{}
        $targetresource= $Myoutput | Where-Object {$_.category -match "resource"}|Group-Object -Property role |Sort-Object -Property Count -Descending -top 10
        $targetresource | ForEach-Object {
            $stats_resource[$_.Name] = $_.Count
        }
        $props["targetresource"] = $stats_resource
    
        $stats_role=@{}
        $targetrole= $Myoutput | Where-Object {$_.category -match "role"}|Group-Object -Property role |Sort-Object -Property Count -Descending -top 10
        $targetrole | ForEach-Object {
            $stats_role[$_.Name] = $_.Count
        }
        $props["targetrole"] = $stats_role

        #$props



        #building the dynamic part of the report
        $myscript="
        
            <script>
                Chart.defaults.plugins.title.font.size = 18;
                const ctx = document.getElementById('myChart');
                new Chart(ctx, {
                    type: 'pie',
                    data: {
                        labels: ["
                        $props.category.Keys | ForEach-Object {
                            $myscript+="'"+$_+"',"
                        }
                        $myscript=$myscript.Replace(",$","") #remove the last comma
                        $myscript+="],
                        datasets: [{
                            label: '# of activities',
                            data: ["
                            $props.category.Keys | ForEach-Object {
                                $myscript+="'"+$props.category[$_]+"',"
                            }
                            $myscript=$myscript.Replace(",$","") #remove the last comma
                            $myscript+="],
                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,
                        radius: 70,
                        layout: {
                            padding: {
                                left: 10, // Adjust this value to push the chart to the left
                            }
                        },
                        plugins: {
                            legend: {
                                display: true,
        
                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Category',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            }
        
                        }
                    }
                });
        
                const ctx4 = document.getElementById('activities');
                new Chart(ctx4, {
                    type: 'pie',
                    data: {
                        labels: ["
                            $props.activity.Keys | ForEach-Object {
                                $myscript+="'"+$_+"',"
                            }
                            $myscript=$myscript.Replace(",$","") #remove the last comma
                            
                        $myscript+="],
        
                        datasets: [{
                            label: '# of activities',
                            data: ["
                            $props.activity.Keys | ForEach-Object {
                                $myscript+="'"+$props.activity[$_]+"',"
                            }
                            $myscript=$myscript.Replace(",$","") #remove the last comma
                            $myscript+="],
                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,
                        radius: 70,
                        layout: {
                            padding: {
                                left: 10, // Adjust this value to push the chart to the left
                            }
                        },
                        plugins: {
                            legend: {
                                display: true,
        
                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Activity type',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            }
        
                        }
                    }
                });
        
                const ctx2 = document.getElementById('result');
                new Chart(ctx2, {
                    type: 'pie',
                    data: {
                        labels: ["
                        $props.result.Keys | ForEach-Object {
                            $myscript+="'"+$_+"',"
                        }
                        $myscript=$myscript.Replace(",$","") #remove the last comma
                        $myscript+="],
                        datasets: [{
                            label: 'result',
                            data: ["
                            $props.result.Keys | ForEach-Object {
                                $myscript+="'"+$props.result[$_]+"',"
                            }
                            $myscript=$myscript.Replace(",$","") #remove the last comma
                            $myscript+="],
                            backgroundColor: [
                                'rgb(0, 255, 0)',
                                'rgb(255, 0, 0)'
                            ],
                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,
                        radius: 70,
                        layout: {
                            padding: {
                                left: 10, // Adjust this value to push the chart to the left
                            }
                        },
                        plugins: {
                            legend: {
                                display: true,
        
                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Result',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            },
        
        
                        }
        
        
                    }
                });
        
        
                const ctx3 = document.getElementById('requestor');
                new Chart(ctx3, {
                    type: 'bar',
                    data: {
                        labels: ["
                        $props.requestor.Keys | ForEach-Object {
                            $myscript+="'"+$_+"',"
                        }
                        $myscript=$myscript.Replace(",$","") #remove the last comma
                        $myscript+="],
                        datasets: [{
                            label: 'Number of requests',
                            data: ["
                            $props.requestor.Keys | ForEach-Object {
                                $myscript+="'"+$props.requestor[$_]+"',"
                            }
                            $myscript=$myscript.Replace(",$","") #remove the last comma
                            $myscript+="],
        
                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,
        
        
                        indexAxis: 'y',
                        plugins: {
                            legend: {
                                display: false,
        
                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Top 10 Requestors',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            },
        
        
                        }
        
        
                    }
                });
        
                const ctx5 = document.getElementById('Groups');
                new Chart(ctx5, {
                    type: 'bar',
                    data: {
                        labels: ["
                        $props.targetGroup.Keys | ForEach-Object {
                            $myscript+="'"+$_+"',"
                        }
                        $myscript=$myscript.Replace(",$","") #remove the last comma
                        $myscript+="],
                        datasets: [{
                            label: 'Number of requests',
                            data: ["
                            $props.targetGroup.Keys | ForEach-Object {
                                $myscript+="'"+$props.targetGroup[$_]+"',"
                            }
                            $myscript=$myscript.Replace(",$","") #remove the last comma
                            $myscript+="],
        
                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,
        
        
                        indexAxis: 'y',
                        plugins: {
                            legend: {
                                display: false,
        
                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Top 10 Groups requested',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            },
        
        
                        }
        
        
                    }
                });

                const ctx6 = document.getElementById('Resources');
                new Chart(ctx6, {
                    type: 'bar',
                    data: {
                        labels: ["
                        $props.targetResource.Keys | ForEach-Object {
                            $myscript+="'"+$_+"',"
                        }
                        $myscript=$myscript.Replace(",$","") #remove the last comma
                        $myscript+="],
                        datasets: [{
                            label: 'Number of requests',
                            data: ["
                            $props.targetresource.Keys | ForEach-Object {
                                $myscript+="'"+$props.targetresource[$_]+"',"
                            }
                            $myscript=$myscript.Replace(",$","") #remove the last comma
                            $myscript+="],
        
                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,
        
        
                        indexAxis: 'y',
                        plugins: {
                            legend: {
                                display: false,
        
                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Top 10 Azure role requested',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            },
        
        
                        }
        
        
                    }
                });

                const ctx7 = document.getElementById('Roles');
                new Chart(ctx7, {
                    type: 'bar',
                    data: {
                        labels: ["
                        $props.targetrole.Keys | ForEach-Object {
                            $myscript+="'"+$_+"',"
                        }
                        $myscript=$myscript.Replace(",$","") #remove the last comma
                        $myscript+="],
                        datasets: [{
                            label: 'Number of requests',
                            data: ["
                            $props.targetrole.Keys | ForEach-Object {
                                $myscript+="'"+$props.targetrole[$_]+"',"
                            }
                            $myscript=$myscript.Replace(",$","") #remove the last comma
                            $myscript+="],
        
                            hoverOffset: 10
                        }]
                    },
                    options: {
                        responsive: false,
        
        
                        indexAxis: 'y',
                        plugins: {
                            legend: {
                                display: false,
        
                                position: 'right',
                            },
                            title: {
                                display: true,
                                text: 'Top 10 Entra role requested',
                                position: 'top',
                                padding: {
                                    top: 10
                                }
                            },
        
        
                        }
        
        
                    }
                });
        
            </script>
        </body>
        
        </html>"

        #$myscript


        $html = @'

        <html>

<head>
    <title>EasyPIM: Activity summary</title>

</head>
<style>
    #container {
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        /* Optional: Adds some space between the divs */
    }

    .row {
        display: flex;
        padding: 10px;
    }

    .chart {
        flex: 1;
        /* Optional: Each div will take up an equal amount of space */
    }

    .description {
        flex: 1;
        /* Optional: Each div will take up an equal amount of space */
        vertical-align: middle;
    }

    code {
        font-family: Consolas, "Courier New", monospace;
        background-color: #f6f8fa;
        padding: 0.2em 0.4em;
        font-size: 85%;
        border-radius: 6px;
    }
    #fixedDiv {
    position: fixed;
    top: 0;
    right: 0;
    width: 200px; /* Adjust as needed */
    height: 200px; /* Adjust as needed */
    background-color: #f6f8fa; /* Adjust as needed */
    padding: 10px; /* Adjust as needed */
    z-index: 1000; /* Ensure the div stays on top of other elements */
}
</style>

<body>
    <div id="fixedDiv">Navigation
        <ul>
            <li><a href="#myChart">Category</a></li>
            <li><a href="#result">Result</a></li>
            <li><a href="#activities">Activities</a></li>
            <li><a href="#requestor">Requestor</a></li>
            <li><a href="#Groups">Groups</a></li>
            <li><a href="#Resources">Azure Roles</a></li>
            <li><a href="#Roles">Entra Roles</a></li>
        </ul>
    </div>
    <div id="container" style="width: 950px">
        <div class="row">
            <div class="chart">
                <canvas id="myChart" width="900" height="180"></canvas>
            </div>
        </div>
        <div class="row">
            <div class="description">
                Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
                consult the details:<br>
                <code>$r | where-object {$_.category -eq "GroupManagement"}</code>
            </div>
        </div>

        <div class="row">
            <div class="chart">
                <canvas id="result" width="900" height="300"></canvas>
            </div>
        </div>
        <div class="row">
            <div class="description">
                Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
                consult the details:<br>
                <code>$r | where-object {$_.result -eq "Failure"}</code>
            </div>
        </div>
    </div>

    <div class="row">
        <div class="chart">
            <canvas id="activities" width="900" height="300"></canvas>
        </div>

    </div>
    <div class="row">
        <div class="description">Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
            consult the details:<br>
            <code>$r | where-object {$_.activity -eq "Add member to role in PIM requested (timebound)"}</code>
        </div>
    </div>

    <div class="row">
        <div class="chart">
            <canvas id="requestor" width="900" height="300"></canvas>
        </div>
    </div>
    <div class="row">
        <div class="description">Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
            consult the details:<br>
            <code>$r | where-object {$_.Initiatedby -match "basic"}</code>
        </div>
</div>
        <div class="row">
        <div class="chart">
            <canvas id="Groups" width="900" height="300"></canvas>
        </div>
    </div>
    <div class="row">
        <div class="description">Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
            consult the details:<br>
            <code>$r | where-object {$_.category -match "group" -and $_.targetresources -eq "PIM_GuestAdmins"}</code>
        </div>
        </div>
        <div class="row">
        <div class="chart">
            <canvas id="Resources" width="900" height="300"></canvas>
        </div>
    </div>
    <div class="row">
        <div class="description">Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
            consult the details:<br>
            <code>$r | where-object {$_.category -match "resource" -and $_.role -eq "Reader"}</code>
        </div>
        </div>

        <div class="row">
        <div class="chart">
            <canvas id="Roles" width="900" height="300"></canvas>
        </div>
    </div>
    <div class="row">
        <div class="description">Assuming this page was generated with <code>$r=show-PIMreport</code>, you can use the following code to
            consult the details:<br>
            <code>$r | where-object {$_.category -match "role" -and $_.role -eq "Global Administrator"}</code>
        </div>
        </div>

    </div> <!-- container -->

    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

'@
        $html += $myscript
        $html | Out-File -FilePath "$env:temp\PIMReport.html" -Force
        invoke-item "$env:temp\PIMReport.html"

    }
    catch {
        MyCatch $_
    }
}