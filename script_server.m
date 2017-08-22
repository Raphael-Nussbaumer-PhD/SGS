%% SECTION: COMPUTATIONAL SAVING

clear all;

% General setting
parm.k.covar(1).model = 'spherical';
parm.k.covar(1).azimuth = 0;
parm.k.covar(1).c0 = 1;
parm.k.covar(1).alpha = 1;
parm.seed_path = 'default';
parm.seed_search = 'shuffle';
parm.seed_U = 'default';

parm.k.covar(1).range0 = [15 15];
parm.k.wradius = 1;
parm.n_real = 1;
parm.saveit = 0;

parm.mg = 1;


N=2.^[8 10 13]+1;%[255 511 1023 2047 4095 8191];
K=[20 52 108];


for i_n=1:numel(N)
    for i_k=1:numel(K)
        nx = N(i_n); % no multigrid
        ny = N(i_n);
        parm.k.nb = K(i_k);
        
        [~,t] = SGS_cst_par(nx,ny,parm);
        title = ['T_cst_par_' num2str(N(i_n)) 'N_' num2str(K(i_k)) 'K' ];
        %save(['./cst_path_paper/' title ],'parm','t')
        T_cst_par_g(i_n,i_k) = t.global;
        T_cst_par_real(i_n,i_k) = t.real;
        
        [~,t] = SGS_trad(nx,ny,parm);
        title = ['T_trad_' num2str(N(i_n)) 'N_' num2str(K(i_k)) 'K' ];
        %save(['./cst_path_paper/' title ],'parm','t')
        T_trad_g(i_n,i_k) = t.global;
    end
end


% Load
for i_n=1:numel(N)-1
    for i_k=1:numel(K)
        title = ['T_trad_' num2str(N(i_n)) 'N_' num2str(K(i_k)) 'K' ];
        load(['./cst_path_paper/' title ])
        
        %T_cst_par_g(i_n,i_k) = t.global;
        %T_cst_par_real(i_n,i_k) = t.real;
        T_trad_g(i_n,i_k) = t.global;
    end
end
save(['./cst_path_paper/T_N_K_all'],'parm','T_cst_par_g','T_cst_par_real','T_trad_g','N','K')

figure(1); clf
m=1:10;
for i_n=1:numel(N)-1
    subplot(1,numel(N),i_n); hold on
    for i_k=1:numel(K)
        eta = m*T_trad_g(i_n,i_k) ./ ( T_cst_par_g(i_n,i_k) + (m-1).*T_cst_par_real(i_n,i_k));
        plot(eta,'DisplayName',[num2str(K(i_k))])
    end
    legend; axis equal
end








